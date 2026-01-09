# UniFi Migration - Troubleshooting Guide

## Issues Encountered During January 9, 2026 Migration Attempt

---

## Issue 1: Switches Not Reconnecting After CloudKey Migration

### Symptoms
- CloudKey successfully moved to new network (172.16.4.9)
- CloudKey accessible via web interface
- All switches showing "Offline" in controller
- Switches not adopting to new controller IP

### Root Cause
Switches still had static or DHCP IP addresses from the old network (192.168.168.x from SonicWall). When CloudKey moved to a different subnet (172.16.4.x), switches couldn't reach the controller because:
1. Different subnet (no Layer 2 connectivity)
2. FortiGate has no inter-VLAN routing between these networks (CMMC isolation requirement)

### Solution
Switches need to be on the same VLAN as CloudKey OR inter-VLAN routing must be enabled. Options:

**Option A: Power Cycle Switches (Force DHCP Renewal)**
1. Ensure FortiGate DHCP is configured on target VLAN
2. Ensure switch uplink ports are on correct VLAN
3. Power cycle each switch
4. Switch will get new IP from FortiGate DHCP
5. Should reconnect to controller

**Option B: Move Switch Uplink Ports to CloudKey VLAN**
1. Change switch uplink port Native VLAN to match CloudKey's VLAN
2. Power cycle switch
3. Gets IP on same VLAN as CloudKey
4. Reconnects automatically

**Option C: Enable Temporary Inter-VLAN Routing**
1. Create firewall policy on FortiGate: old VLAN ↔ CloudKey VLAN
2. Switches can reach controller across VLANs
3. Migrate switches one by one
4. Remove policy when done

### Prevention
- Change all devices to DHCP *after* switching to new firewall, not before
- Ensure all switch ports are pre-configured for correct VLANs
- Test with one device before migrating everything

---

## Issue 2: CloudKey Shows "No Internet" Globe

### Symptoms
- Can access CloudKey web interface locally
- CloudKey shows red "no internet" globe icon
- May or may not affect functionality

### Root Causes

**Cause A: Gateway Not Reachable**
- CloudKey can't reach configured gateway
- Wrong gateway IP configured
- Gateway on wrong VLAN

**Cause B: No Internet Route**
- Gateway reachable but no internet access
- FortiGate firewall policy missing
- DNS not working

**Cause C: Temporary During Network Changes**
- CloudKey still checking old gateway
- Takes time to update status
- May resolve itself in 1-2 minutes

### Solutions

**Test 1: Check Gateway Connectivity**
```bash
ssh root@<cloudkey-ip>
ping -c 3 <gateway-ip>
```
If fails: Gateway IP wrong or not on same VLAN

**Test 2: Check Internet**
```bash
ping -c 3 8.8.8.8
```
If fails: No internet route from gateway

**Test 3: Check DNS**
```bash
ping -c 3 google.com
```
If fails: DNS not working

**Fix Gateway Issues:**
1. Verify CloudKey IP matches port VLAN
2. Verify gateway IP is correct in config
3. Verify gateway exists on that VLAN

**Fix Internet Issues:**
1. Check FortiGate firewall policy allows that VLAN → WAN
2. Check NAT is enabled on policy
3. Test from FortiGate itself

**Wait It Out:**
If tests pass but globe still red, wait 5 minutes and refresh

---

## Issue 3: Switch Gets Wrong VLAN IP After Power Cycle

### Symptoms
- Power cycled switch to force DHCP renewal
- Switch came back with IP in wrong subnet
- Example: Expected 192.168.168.x, got 192.168.1.20

### Root Cause
The **port the switch is plugged into** has Native VLAN set to wrong network. Switch gets DHCP from whatever VLAN the port is configured for, regardless of what you expect.

### Solution

**Step 1: Identify Switch Uplink Port**
1. In UniFi Controller, find the switch that's upstream
2. Look at port diagram
3. Find which port shows the downstream switch connected

**Step 2: Check Port VLAN**
1. Click on that port
2. Check "Native VLAN / Network"
3. It's probably set to wrong VLAN

**Step 3: Change Port VLAN**
1. Change Native VLAN to correct network
2. Apply
3. Power cycle downstream switch again
4. Should get correct IP now

### Example
- Switch got 192.168.1.20 (Default VLAN 1)
- Wanted 192.168.168.x (Management VLAN 2)
- Uplink port was set to "Default (1)"
- Changed to "Management (2)"
- Power cycled switch
- Got correct IP

---

## Issue 4: Can't SSH to CloudKey

### Symptoms
- Can access CloudKey web interface
- SSH connection refused or times out
- `ssh root@<cloudkey-ip>` fails

### Root Causes

**Cause A: SSH Not Enabled**
- SSH service disabled in UniFi OS settings

**Cause B: Wrong Credentials**
- Password not set or unknown
- Using wrong username

**Cause C: Firewall Blocking**
- FortiGate blocking SSH between VLANs
- SSH allowed on same VLAN but blocked across VLANs

**Cause D: SSH Service Not Running**
- UniFi OS SSH service crashed
- Need to restart service

### Solutions

**Enable SSH (via Web Interface):**
1. Access UniFi OS web interface
2. System → Console (or Advanced)
3. Look for SSH toggle
4. Enable SSH
5. Set/change password if prompted

**Verify Credentials:**
- Username: `root` (always root for CloudKey Gen2 Plus)
- Password: Your UniFi OS admin password OR custom SSH password if set separately

**Test from Same VLAN:**
- Connect laptop to same VLAN as CloudKey
- Try SSH from there
- If works: Firewall blocking cross-VLAN SSH
- If fails: SSH service issue

**Check FortiGate Policies:**
- If accessing from different VLAN, check inter-VLAN policy
- Ensure policy allows all traffic or specifically SSH (port 22)

**Restart SSH Service (requires console access):**
- Connect via console cable
- Login as root
- `systemctl restart ssh`

---

## Issue 5: Inter-VLAN Routing Not Working Despite Policies

### Symptoms
- FortiGate has firewall policies allowing VLAN A ↔ VLAN B
- Devices on VLAN A can't reach devices on VLAN B
- Ping fails across VLANs

### Root Causes

**Cause A: Return Traffic Policy Missing**
- Policy exists for A → B
- But no policy for B → A (return traffic)

**Cause B: Policy Order**
- Deny policy above allow policy
- Traffic being blocked by earlier rule

**Cause C: NAT Incorrectly Enabled**
- NAT enabled on inter-VLAN policy
- Breaks return path

**Cause D: VLAN Not Trunked on Switch**
- FortiGate configured correctly
- But switch not passing VLAN traffic

### Solutions

**Check Bidirectional Policies:**
```
Policy 1: internal1.2 → internal1.4 (ACCEPT, NAT OFF)
Policy 2: internal1.4 → internal1.2 (ACCEPT, NAT OFF)
```
Need BOTH directions

**Check Policy Order:**
- Policies processed top to bottom
- Move allow policies above deny policies if needed

**Disable NAT on Inter-VLAN Policies:**
- NAT should only be used for traffic to WAN
- Inter-VLAN traffic should have NAT OFF

**Verify Switch Trunk:**
- Switch uplink to FortiGate must trunk all VLANs
- Check switch port configuration
- Tagged VLAN Management: Include all needed VLANs

**Test from FortiGate:**
```bash
# Test connectivity from FortiGate itself
execute ping-options source <vlan-ip>
execute ping <destination-ip>
```

---

## Issue 6: SonicWall Gateway Was Wrong (192.168.168.1 vs .168)

### Symptoms
- Changed CloudKey to 192.168.168.30
- Set gateway to 192.168.168.1
- No connectivity

### Root Cause
SonicWall default LAN was **192.168.168.168/24**, not .168.1. The SonicWall itself was at .168, not .1.

### Solution
Changed gateway to correct IP (192.168.168.168) and connectivity restored.

### Lesson
Always verify the actual gateway IP of existing equipment before using it in configuration.

**How to Find Gateway:**
```bash
# From a working device on that network
ip route
# Look for "default via X.X.X.X"

# Or
cat /etc/resolv.conf
# Gateway often same as DNS server in small networks

# Or check existing device configs
# Switches/APs will have gateway configured
```

---

## Issue 7: Creating Networks in UniFi Doesn't Create VLANs on Switches

### Symptoms
- Created "Management (VLAN 2)" network in UniFi
- Expected it to automatically work
- Traffic not flowing

### Root Cause
**UniFi Networks define networks, but:**
1. Switch ports must be explicitly configured to use those networks
2. Upstream firewall (FortiGate) must also have those VLANs configured
3. VLANs must be trunked between switches and firewall
4. Creating a network alone doesn't activate it

### Solution

**For Each Network Created:**

1. **Configure Switch Ports**
   - Decide which ports should be on this network
   - Change Port "Native VLAN" to the network
   - For trunks, add to "Tagged VLAN Management"

2. **Configure Upstream Firewall**
   - Create VLAN interface on FortiGate
   - Assign IP address (becomes gateway)
   - Create DHCP server if needed
   - Create firewall policies for traffic flow

3. **Trunk VLANs**
   - Uplink from switch to FortiGate must trunk all VLANs
   - Inter-switch connections must trunk all VLANs
   - Set port type to trunk, add VLANs to "Tagged VLAN Management"

4. **Test Connectivity**
   - Connect device to port on new VLAN
   - Verify gets DHCP IP
   - Verify can reach gateway
   - Verify can reach internet

### Best Practice
- Configure FortiGate VLAN first
- Then create UniFi Network matching that VLAN
- Then configure switch ports
- Test before using in production

---

## Issue 8: Both Firewalls Connected Simultaneously

### Symptoms
- Both SonicWall and FortiGate plugged in at same time
- Connectivity issues
- Devices confused about which gateway to use

### Root Cause
**Multiple DHCP servers and gateways:**
- Both firewalls serving DHCP on same VLAN
- Devices getting inconsistent information
- Some devices using SonicWall, some using FortiGate
- Routing conflicts

### Solution
**Never have both firewalls active on same network simultaneously.**

**During Migration:**
1. Disconnect old firewall completely
2. Connect new firewall
3. Test and verify
4. If need to rollback, disconnect new and reconnect old

**If Accidentally Connected Both:**
1. Immediately disconnect one (usually the old one)
2. Power cycle any confused devices
3. Verify DHCP leases are from correct firewall
4. Clear DHCP leases on old firewall if possible

---

## Common Error Messages and Solutions

### "Device Not Responding" in UniFi Controller

**Possible Causes:**
- Device offline/powered off
- Network connectivity issue
- Device has wrong IP and can't reach controller
- Controller service crashed

**Troubleshooting:**
1. Check if device has power (LEDs on?)
2. Check physical cable connection
3. Check switch port is active and correct VLAN
4. Try accessing device directly by IP
5. Check controller service status: `systemctl status unifi`

### "Adopting" Status Stuck

**Possible Causes:**
- Device can reach controller but provision failing
- Firmware mismatch
- Configuration error

**Solutions:**
1. Wait 5-10 minutes (can take time)
2. SSH to device: `set-inform http://<controller-ip>:8080/inform`
3. Restart device: `reboot`
4. Check controller logs for errors
5. Factory reset device and re-adopt if persistent

### "Isolated" Status

**Cause:**
Device detected that it's on wrong VLAN or can't reach other network devices properly.

**Solution:**
1. Check device's VLAN configuration
2. Verify port VLAN matches expectations
3. Check if device needs to be on management VLAN vs client VLAN
4. Verify inter-VLAN routing if needed

---

## Diagnostic Commands

### FortiGate

```bash
# Check interface status
get system interface physical

# Check DHCP leases
diagnose ip dhcp lease list

# Check routing
get router info routing-table all

# Check policy hit count
diagnose firewall iprope list 100000

# Packet capture
diagnose sniffer packet internal1.4 'host 172.16.4.9' 4 0 l

# Check VLAN status
diagnose switch-controller dump vlan

# Test connectivity
execute ping <ip>
execute traceroute <ip>
```

### UniFi CloudKey

```bash
# Check interface status
ip addr show
ip link show

# Check routing
ip route
route -n

# Check connectivity
ping -c 3 <gateway>
ping -c 3 8.8.8.8

# Check DNS
nslookup google.com
dig google.com

# Check UniFi service
systemctl status unifi
journalctl -u unifi -n 50

# Check network config
cat /etc/systemd/network/eth0.network

# Restart networking
systemctl restart systemd-networkd

# Check listening ports
netstat -tlnp | grep -E '(8080|8443)'
```

### UniFi Devices (Switches/APs)

```bash
# SSH to device
ssh ubnt@<device-ip>

# Check device info
info

# Check adoption status
info | grep -E '(Status|state)'

# Reboot
reboot

# Force adoption
set-inform http://<controller-ip>:8080/inform

# Check connectivity
ping <controller-ip>
```

---

## When to Consider Starting Over

### Red Flags for Fresh Start:

1. **Configuration Corruption**
   - Settings not applying
   - Devices stuck in weird states
   - Controller behaving erratically

2. **Lost Track of Changes**
   - Don't know what's configured where
   - Multiple failed attempts layered on each other
   - Can't identify what's causing issues

3. **Time Investment**
   - Spent more time troubleshooting than fresh setup would take
   - Maintenance window running out
   - Need to restore service quickly

### Fresh Start Checklist:

1. **Document Current State**
   - Full backup of UniFi configuration
   - Screenshot all important settings
   - Note all device IPs and locations

2. **Plan New Configuration**
   - Decide on VLAN structure
   - Plan IP addressing
   - Design port configurations

3. **Execute Clean Migration**
   - Factory reset CloudKey (if needed)
   - Set up on FortiGate network from start
   - Adopt devices one by one
   - Restore configuration from backup

4. **Verify Everything**
   - Test all functionality
   - Verify all devices working
   - Create fresh backup

---

## Prevention for Next Time

### Pre-Migration Prep

1. **Full Documentation**
   - Backup everything
   - Document all configurations
   - Screenshot critical settings

2. **Test Environment**
   - Test with one device first
   - Verify DHCP working on new network
   - Confirm internet access

3. **Staged Migration**
   - Move CloudKey first
   - Verify it works
   - Then move devices one at a time

4. **Clear Rollback Plan**
   - Know exactly how to roll back
   - Test rollback process
   - Have backup hardware ready if needed

### During Migration

1. **One Change at a Time**
   - Don't change multiple things simultaneously
   - Verify each change before next

2. **Document as You Go**
   - Note what you changed
   - Note results
   - Makes troubleshooting easier

3. **Have Backup Access**
   - Console cable ready
   - Direct laptop connection available
   - Don't rely solely on network access

---

**Last Updated:** January 9, 2026
**Status:** Based on actual issues encountered during migration attempt
