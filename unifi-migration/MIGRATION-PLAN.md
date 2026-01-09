# UniFi CloudKey Plus Migration Plan

## Current State (Paused - January 9, 2026)

**Status:** Migration paused - reverted to original SonicWall configuration

### Working Configuration
- **SonicWall:** In place and operational
- **CloudKey Gen2 Plus:** 192.168.168.x on SonicWall network
- **All UniFi Devices:** Online and connected to controller
- **Management:** Working through SonicWall

---

## Goal

Migrate UniFi CloudKey Plus and all managed devices from SonicWall network to FortiGate network without breaking connectivity.

### Target Configuration
- **CloudKey IP:** 172.16.4.9 (CBS-Corp VLAN 4)
- **UniFi Devices:** DHCP on VLAN 4 (172.16.4.100-200 range)
- **Gateway:** FortiGate at 172.16.4.1
- **Management:** All through FortiGate

---

## Current Network Configuration

### SonicWall VLANs (Original)
- **X0:** 192.168.168.168/24 - Default LAN
- **X0:V3:** 172.16.3.1/24 - IoT Guest Network
- **X0:V4:** 172.16.4.1/24 - CORP-LAN
- **X0:V5:** 172.16.5.1/24 - Studio-LAN
- **X0:V6:** 172.16.6.1/24 - Guest Network
- **X1:V847:** 204.186.251.250/30 - WAN VLAN 847

### FortiGate VLANs (Configured)
- **internal1.2:** 192.168.168.168/24 - Management (temporary bridge network)
- **internal1.3:** 172.16.3.1/24 - IoT Guest Network
- **internal1.4:** 172.16.4.1/24 - CORP-LAN (target network)
- **internal1.5:** 172.16.5.1/24 - Studio-LAN
- **internal1.6:** 172.16.6.1/24 - Guest Network
- **wan1.847:** 204.186.251.250/30 - WAN VLAN 847

### UniFi Networks Configured
- **Default (VLAN 1):** 192.168.1.0/24
- **Management (VLAN 2):** 192.168.168.0/24 (created during migration attempt)
- **Guest (VLAN 3):** 172.16.3.0/24
- **CBS-Corp (VLAN 4):** 172.16.4.0/24
- **Studio VLAN (VLAN 5):** 172.16.5.0/24
- **Guest Wi-Fi (VLAN 6):** 172.16.6.0/24

---

## CloudKey Information

### Device Details
- **Model:** UniFi CloudKey Gen2 Plus (UCK-G2-PLUS)
- **Hostname:** CBS-UCKGen2
- **Current IP:** 192.168.168.30/24
- **Gateway:** 192.168.168.168 (SonicWall)
- **UniFi OS Version:** 4.4.3
- **Network Application:** 10.0.160

### Access
- **Web Interface:** https://192.168.168.30
- **SSH:** `ssh root@192.168.168.30`
- **SSH Password:** Configured (user set custom password)
- **Network Config Location:** `/etc/systemd/network/eth0.network`

### Network Config File Format
```
[Match]
Name=eth0

[Network]
DNS=1.1.1.1
DNS=8.8.8.8

[Address]
Address=192.168.168.30/24

[Route]
Gateway=192.168.168.168
```

### To Edit Network Config
```bash
# View current config
cat /etc/systemd/network/eth0.network

# Edit with vi
vi /etc/systemd/network/eth0.network

# Or use sed for quick changes
sed -i 's/Address=192.168.168.30/Address=172.16.4.9/' /etc/systemd/network/eth0.network
sed -i 's/Gateway=192.168.168.168/Gateway=172.16.4.1/' /etc/systemd/network/eth0.network

# Apply changes
systemctl restart systemd-networkd

# Verify
ip addr show eth0
ip route
```

---

## UniFi Devices Status

### Device Configuration
- **All switches:** Currently set to DHCP (changed during migration attempt)
- **All switches:** Currently have 192.168.168.x IPs from SonicWall DHCP
- **Management Port:** Unknown which port CloudKey is currently on (likely Port 10)

### SSH Access to UniFi Devices
- **Method:** Via UniFi Controller → Settings → System → Advanced → Device Authentication
- **Note:** In UniFi OS 4.4.3, this setting location differs from newer versions
- **Credentials:** User has not yet confirmed these in the controller

---

## What We Tried

### Attempt 1: Direct Migration with Port Swap
1. ✅ Changed Port 9 to CBS-Corp VLAN 4
2. ✅ Changed CloudKey IP to 172.16.4.9
3. ✅ Moved CloudKey to Port 9
4. ❌ Switches didn't reconnect - still had old 192.168.168.x IPs from SonicWall

**Issue:** Switches had DHCP IPs from SonicWall, couldn't reach CloudKey on different subnet

### Attempt 2: Bridge via Management VLAN
1. ✅ Created "Management" network (VLAN 2) in UniFi for 192.168.168.0/24
2. ✅ Configured FortiGate internal1.2 with 192.168.168.168/24
3. ✅ Enabled inter-VLAN routing on FortiGate (VLAN 2 ↔ VLAN 4)
4. ✅ Changed CloudKey back to 192.168.168.30
5. ✅ Changed Port 7 to Management VLAN
6. ❌ CloudKey worked but switches still offline
7. ❌ Attempted to power cycle one switch - got wrong VLAN IP (192.168.1.20)

**Issue:** Switch port VLAN confusion, complexity with multiple VLANs

### Attempt 3: Stay on SonicWall, Use Existing VLAN 4
1. Recognized VLAN 4 exists on both SonicWall and FortiGate
2. Attempted to change CloudKey to VLAN 4 while on SonicWall
3. ❌ User determined this wasn't working

**Issue:** Unknown - migration paused before troubleshooting

---

## Lessons Learned

### Key Issues Encountered

1. **DHCP Timing Problem**
   - Switches got DHCP IPs from SonicWall before switching to FortiGate
   - Switches don't automatically renew DHCP when firewall changes
   - Need to power cycle switches to force DHCP renewal

2. **VLAN Configuration Complexity**
   - Multiple VLANs (Default 1, Management 2, CBS-Corp 4) caused confusion
   - Port VLAN assignments must match device expectations
   - Switch ports for uplinks need careful VLAN configuration

3. **Inter-VLAN Routing Required**
   - FortiGate has VLANs isolated by default (CMMC requirement)
   - Need inter-VLAN routing policies if using bridge network
   - Policies exist but didn't resolve connectivity

4. **CloudKey Network Config**
   - CloudKey Gen2 Plus uses systemd-networkd (not netplan)
   - Config file: `/etc/systemd/network/eth0.network`
   - Must restart systemd-networkd after changes

5. **UniFi Device Discovery**
   - Devices use Layer 2 discovery to find controller
   - Works within same VLAN automatically
   - Across VLANs requires proper routing

---

## Recommended Approach for Next Attempt

### Prerequisites (Do Before Migration Day)

1. **Document Everything**
   - [ ] Create full site backup via UniFi Controller
   - [ ] Export/screenshot all switch port configurations
   - [ ] Document which devices are on which switch ports
   - [ ] Document current IP addresses of all critical devices
   - [ ] Note any port profiles or custom configurations

2. **Verify FortiGate Configuration**
   - [ ] Confirm VLAN 4 (CBS-Corp) exists: 172.16.4.1/24
   - [ ] Confirm DHCP server on internal1.4: range 172.16.4.100-200
   - [ ] Confirm firewall policy: internal1.4 → wan1.847 (internet access)
   - [ ] Confirm DNS servers: 1.1.1.1, 8.8.8.8
   - [ ] Test DHCP by connecting a laptop to VLAN 4 port

3. **Configure UniFi Switch Ports (While on SonicWall)**
   - [ ] Identify which port CloudKey is plugged into
   - [ ] Identify which ports have switches plugged in (uplinks)
   - [ ] Identify which ports have APs plugged in
   - [ ] Create a test port on CBS-Corp VLAN 4 (use a spare port)
   - [ ] Verify SonicWall has VLAN 4 available

### Migration Day - Clean Cut Approach

**Goal:** Move everything to VLAN 4 in one coordinated migration

#### Phase 1: Test with One Device (30 minutes)

1. **Connect test device to FortiGate VLAN 4**
   - Configure spare port on switch for CBS-Corp VLAN 4
   - Plug in a laptop with DHCP
   - Verify it gets IP in 172.16.4.100-200 range
   - Test internet access (ping 8.8.8.8)
   - Test DNS (ping google.com)

2. **If test fails, stop and troubleshoot FortiGate before proceeding**

#### Phase 2: Migrate CloudKey (15 minutes)

**Important:** Have console/direct access to CloudKey as backup

1. **Update CloudKey network config via SSH**
   ```bash
   ssh root@192.168.168.30

   # Backup current config
   cp /etc/systemd/network/eth0.network /root/eth0.network.backup

   # Change to new network
   sed -i 's/Address=192.168.168.30/Address=172.16.4.9/' /etc/systemd/network/eth0.network
   sed -i 's/Gateway=192.168.168.168/Gateway=172.16.4.1/' /etc/systemd/network/eth0.network

   # Verify changes
   cat /etc/systemd/network/eth0.network

   # Apply (will disconnect)
   systemctl restart systemd-networkd
   ```

2. **Immediately change CloudKey port VLAN**
   - In UniFi Controller (you'll lose access after this step)
   - Find CloudKey port (let's say Port 10)
   - Change Native VLAN from current to **CBS-Corp (4)**
   - Apply

3. **Switch from SonicWall to FortiGate**
   - Unplug network cable from SonicWall
   - Plug into FortiGate (ensure VLAN 4 is trunked)

4. **Access CloudKey at new IP**
   - Wait 1-2 minutes
   - Access: https://172.16.4.9
   - Verify controller accessible
   - All devices will show offline (expected)

#### Phase 3: Migrate All Switches (1-2 hours)

**Option A: Power Cycle All at Once (Fast but Risky)**
1. Power off all switches simultaneously
2. Wait 30 seconds
3. Power on all switches
4. Wait 5 minutes for boot and DHCP
5. Check controller for devices coming online
6. If problems, more difficult to troubleshoot

**Option B: One Switch at a Time (Slower but Safer)**

For each switch:

1. **Note current switch port VLAN**
   - What VLAN is the uplink port on?
   - Change it to CBS-Corp VLAN 4 if needed

2. **Power cycle the switch**
   - Unplug power
   - Wait 10 seconds
   - Plug back in

3. **Wait for reconnection (2-3 minutes)**
   - Watch for device to appear in controller
   - Should get IP in 172.16.4.100-200
   - Status should go: Adopting → Provisioning → Connected

4. **Verify switch is working**
   - Check it has internet access
   - Check connected devices still work
   - Check any APs on this switch

5. **Move to next switch**

**Recommended:** Start with edge switches (furthest from core), work back to core switches

#### Phase 4: Verify Everything (30 minutes)

1. **Check all devices online**
   - All switches showing "Connected"
   - All APs showing "Connected"
   - All have IPs in 172.16.4.x range

2. **Test connectivity**
   - Client devices can access internet
   - VLANs are working (if APs using multiple VLANs)
   - Management access from CORP network works

3. **Create backup**
   - Full site backup via UniFi Controller
   - FortiGate config backup
   - Document new configuration

---

## Alternative: Nuclear Option (If Clean Cut Fails)

If migration keeps having issues, consider factory reset and rebuild:

### Steps

1. **Backup Everything First**
   - Full UniFi site backup
   - Export/document all configurations
   - Screenshot everything important

2. **Factory Reset CloudKey**
   - Physical reset button on CloudKey
   - Restore from backup after setting up on new network

3. **Readopt All Devices**
   - Set CloudKey on FortiGate VLAN 4 from the start
   - Factory reset each switch/AP
   - SSH to each device and set-inform to new controller
   - Restore configuration from backup

4. **Reconfigure from Backup**
   - Restore UniFi site backup
   - All port configurations should come back
   - Verify everything works

**Pros:** Clean start, no legacy issues
**Cons:** More downtime, risk of configuration loss if backup incomplete

---

## Rollback Plan

### If Migration Fails - Return to SonicWall

1. **Reconnect SonicWall**
   - Unplug from FortiGate
   - Plug back into SonicWall

2. **Restore CloudKey to Old Network**
   - Via SSH (if accessible):
     ```bash
     ssh root@172.16.4.9  # or whatever IP it has
     sed -i 's/Address=172.16.4.9/Address=192.168.168.30/' /etc/systemd/network/eth0.network
     sed -i 's/Gateway=172.16.4.1/Gateway=192.168.168.168/' /etc/systemd/network/eth0.network
     systemctl restart systemd-networkd
     ```
   - Via direct connection if needed

3. **Revert Port VLANs**
   - Change CloudKey port back to original VLAN
   - Change switch uplink ports back

4. **Power Cycle Switches**
   - Force DHCP renewal from SonicWall
   - Should come back online within 5 minutes

5. **Verify Everything Back to Normal**
   - All devices online
   - Connectivity working
   - Document what went wrong for next attempt

---

## Important Notes

### CMMC Compliance Consideration
- FortiGate has VLANs isolated by default (no inter-VLAN routing)
- This is a CMMC Level 2 requirement
- During migration, temporary inter-VLAN policies were added
- **Remember to remove temporary policies after migration complete**

### SSH Access Reminder
- CloudKey SSH: `root@<cloudkey-ip>` with user-set password
- UniFi device SSH: Check Device Authentication in controller for credentials
- Always test SSH access before migration day

### Port Configuration Tracking
- **Critical:** Know which port CloudKey is on before migration
- **Critical:** Know which ports are switch uplinks
- **Critical:** Know which ports have APs
- Document everything before making changes

### FortiGate Access
- GUI: https://172.16.4.1 (from CORP network)
- User: admin
- Password: 15+ character CMMC-compliant password
- Have console access ready as backup

### Timing Considerations
- DHCP leases take 2-3 minutes to acquire
- Device adoption in UniFi takes 2-5 minutes per device
- Budget 10 minutes per switch for safe migration
- Total time estimate: 2-4 hours depending on number of devices

---

## Questions to Answer Before Next Attempt

1. **How many switches total?** (affects timeline)
2. **How many APs?** (affects timeline)
3. **Which switch is the main/core switch?** (should be migrated last)
4. **What is the CloudKey physically plugged into?** (port and switch)
5. **Are there any critical services that can't have downtime?** (affects strategy)
6. **What are the Device Authentication SSH credentials?** (for manual access if needed)
7. **Is there a maintenance window available?** (timing)
8. **Who needs to be notified of the migration?** (communication plan)

---

## Next Session Checklist

Before resuming migration:

- [ ] Read through this entire document
- [ ] Verify SonicWall is still operational
- [ ] Verify all UniFi devices currently online
- [ ] Create fresh backup of UniFi site
- [ ] Document current port configurations
- [ ] Test FortiGate VLAN 4 DHCP with laptop
- [ ] Confirm SSH access to CloudKey works
- [ ] Have console cable ready for CloudKey
- [ ] Schedule maintenance window
- [ ] Notify users of potential brief outage
- [ ] Have rollback plan printed/available

---

**Created:** January 9, 2026
**Status:** Migration paused - awaiting next attempt
**Current State:** Back to SonicWall, all devices operational
