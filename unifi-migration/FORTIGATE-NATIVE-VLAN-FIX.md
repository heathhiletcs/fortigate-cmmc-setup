# FortiGate Native VLAN Fix for UniFi Migration

**Created:** January 29, 2026
**Status:** Ready to implement
**Purpose:** Match SonicWall X0 untagged network configuration on FortiGate

---

## Problem Summary

The SonicWall has a **Default LAN (X0)** at 192.168.168.168/24 that handles **untagged** traffic. The UniFi gear (CloudKey, switches, etc.) currently lives on this network.

Previous migration attempts created `internal1.2` on the FortiGate with VLAN ID 2, but this requires **tagged** traffic. Since UniFi sends untagged traffic for this network, the FortiGate wasn't processing it correctly.

### SonicWall vs FortiGate Comparison

| SonicWall Interface | IP Address | VLAN Tag | FortiGate Equivalent |
|---------------------|------------|----------|---------------------|
| X0 (Default LAN) | 192.168.168.168/24 | **Untagged** | `internal` (hardware switch) |
| X0:V3 (IoT Guest) | 172.16.3.1/24 | 3 | `internal1.3` |
| X0:V4 (CORP-LAN) | 172.16.4.1/24 | 4 | `internal1.4` |
| X0:V5 (Studio-LAN) | 172.16.5.1/24 | 5 | `internal1.5` |
| X0:V6 (Guest) | 172.16.6.1/24 | 6 | `internal1.6` |
| X1:V847 (WAN) | 204.186.251.250/30 | 847 | `wan1.847` |
| X1:V1449 (WAN2) | 204.186.249.142/30 | 1449 | Not yet configured |

---

## Solution: Configure "internal" Hardware Switch with Native IP

Assign 192.168.168.168/24 directly to the `internal` hardware switch interface. This handles untagged traffic exactly like SonicWall X0.

---

## Pre-Implementation Checklist

Before starting:

- [ ] Have console access to FortiGate (USB-C, 9600 baud) as backup
- [ ] Have GUI access via https://172.16.4.1 (CORP-LAN)
- [ ] Verify current FortiGate config is backed up
- [ ] Confirm SonicWall is still handling production traffic
- [ ] Know the admin password (15+ character CMMC password)

---

## Implementation Steps

### Step 1: Check for Existing internal1.2 Interface

First, see if the previous VLAN 2 attempt still exists:

```bash
# Connect via console or SSH, then:
show system interface internal1.2
```

**If it exists**, you'll need to remove it and any dependencies (policies, DHCP servers).

### Step 2: Remove internal1.2 (If Present)

#### 2a. Check for firewall policies using internal1.2

```bash
show firewall policy
```

Look for any policies with `srcintf` or `dstintf` containing `internal1.2`.

#### 2b. Delete any policies referencing internal1.2

```bash
config firewall policy
    delete <policy-id>
end
```

Replace `<policy-id>` with the actual policy number(s).

#### 2c. Check for DHCP server on internal1.2

```bash
show system dhcp server
```

Look for any DHCP server with `interface internal1.2`.

#### 2d. Delete DHCP server if present

```bash
config system dhcp server
    delete <dhcp-server-id>
end
```

#### 2e. Delete the internal1.2 interface

```bash
config system interface
    delete "internal1.2"
end
```

### Step 3: Configure Native IP on "internal" Hardware Switch

```bash
config system interface
    edit "internal"
        set ip 192.168.168.168 255.255.255.0
        set allowaccess ping https ssh
        set description "Default LAN - Untagged (UniFi Management)"
    next
end
```

### Step 4: Configure DHCP Server for Native Network

**Note:** Skip this if all devices on 192.168.168.0/24 have static IPs.

```bash
config system dhcp server
    edit 0
        set interface "internal"
        set default-gateway 192.168.168.168
        set netmask 255.255.255.0
        set dns-service specify
        set dns-server1 1.1.1.1
        set dns-server2 8.8.8.8
        config ip-range
            edit 1
                set start-ip 192.168.168.100
                set end-ip 192.168.168.200
            next
        end
        set lease-time 86400
    next
end
```

### Step 5: Create Firewall Policy for Internet Access

```bash
config firewall policy
    edit 0
        set name "Default-LAN-to-Internet"
        set srcintf "internal"
        set dstintf "wan1.847"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
        set logtraffic all
        set comments "Default LAN untagged - UniFi management network"
        set status enable
    next
end
```

### Step 6: Verify Configuration

```bash
# Check interface configuration
get system interface internal

# Check DHCP server (if configured)
show system dhcp server

# Check firewall policy
show firewall policy

# Check routing
get router info routing-table all
```

---

## Testing

### Test 1: Ping from FortiGate

```bash
# Ping an external address
execute ping 8.8.8.8

# Ping from the internal interface specifically
execute ping-options source 192.168.168.168
execute ping 8.8.8.8
```

### Test 2: Connect a Device

1. Connect a laptop to any internal port (internal1-5) with **no VLAN tag** (access mode)
2. Set laptop to DHCP
3. Verify it gets an IP in 192.168.168.100-200 range
4. Verify gateway is 192.168.168.168
5. Test internet access (ping 8.8.8.8, browse web)

### Test 3: Verify VLAN Traffic Still Works

Ensure the tagged VLANs (3, 4, 5, 6) still work:

```bash
# Check VLAN interfaces are up
get system interface physical

# Check from a device on VLAN 4 (CORP-LAN)
# Should still have internet access
```

---

## Full Migration After This Fix

Once the FortiGate native VLAN is working:

1. **Physical cutover:** Move the trunk cable from SonicWall to FortiGate
2. **UniFi devices** should automatically get IPs on 192.168.168.0/24 (untagged)
3. **CloudKey** at 192.168.168.30 should be reachable
4. **Tagged VLANs** (3, 4, 5, 6) should continue working for other traffic

The key difference from previous attempts: **No VLAN tag required** for the management network now.

---

## Rollback Plan

If something goes wrong:

### Remove the native IP from internal

```bash
config system interface
    edit "internal"
        unset ip
    next
end
```

### Delete the firewall policy

```bash
config firewall policy
    delete <policy-id-you-created>
end
```

### Delete DHCP server (if created)

```bash
config system dhcp server
    delete <dhcp-server-id>
end
```

### Reconnect to SonicWall

Physically move cables back to SonicWall - everything should work as before.

---

## Important Notes

### CMMC Compliance

- This adds another network segment to the FortiGate
- Traffic logging is enabled on the firewall policy
- Consider whether this network needs isolation from other VLANs (currently no inter-VLAN routing)
- Document this network in your System Security Plan

### VLAN Isolation

By default, FortiGate blocks inter-VLAN traffic. The 192.168.168.0/24 network will be isolated from:
- 172.16.3.0/24 (IoT)
- 172.16.4.0/24 (CORP)
- 172.16.5.0/24 (Studio)
- 172.16.6.0/24 (Guest)

If you need the CloudKey/UniFi management to reach devices on other VLANs, you'll need additional firewall policies.

### Interface Naming

- `internal` = the hardware switch (physical ports internal1-5)
- `internal1.X` = VLAN sub-interfaces (tagged traffic)
- Untagged traffic goes to `internal`, tagged goes to respective `internal1.X`

---

## Quick Reference Commands

```bash
# View all interfaces
show system interface

# View specific interface
get system interface internal

# View firewall policies
show firewall policy

# View DHCP servers
show system dhcp server

# View DHCP leases
execute dhcp lease-list internal

# Test connectivity
execute ping 8.8.8.8

# Check interface status
get system interface physical

# Backup config before changes
execute backup config management-station "pre-native-vlan-fix"
```

---

## Files to Reference

- `CONTEXT.md` - Full FortiGate configuration details
- `MIGRATION-PLAN.md` - Original UniFi migration plan
- `MIGRATION-SUMMARY-20251211.md` - Previous migration work completed
- `SESSION-NOTES.md` - Historical context and decisions

---

**Next Step:** Implement this fix, then proceed with UniFi migration per `MIGRATION-PLAN.md`
