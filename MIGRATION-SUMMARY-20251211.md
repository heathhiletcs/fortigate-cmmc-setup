# FortiGate 60F - Production Migration Summary

**Migration Date:** December 11, 2025
**Status:** ✅ COMPLETE
**Downtime:** Minimal (estimated < 5 minutes)

---

## Migration Overview

Successfully migrated from test WAN configuration to production fiber WAN (VLAN 847) and activated all internal VLANs for office network connectivity.

### What Was Migrated

**From:** Test WAN configuration (wan1 DHCP)
**To:** Production fiber WAN (wan1.847 VLAN 847)

**Network Segments Activated:**
- VLAN 3: IoT Guest Network (172.16.3.0/24)
- VLAN 4: CORP-LAN (172.16.4.0/24)
- VLAN 5: Studio-LAN (172.16.5.0/24)
- VLAN 6: Guest Network (172.16.6.0/24)

---

## Pre-Migration Status

### Configuration State
- ✅ WAN VLAN 847 pre-configured but interface administratively DOWN
- ✅ All internal VLANs configured with DHCP
- ✅ Firewall policies created and pointing to wan1.847
- ✅ Default route configured
- ⚠️ Internal hard-switch interface administratively DOWN
- ⚠️ Physical cables not connected

### Physical Connectivity
- Fiber ISP cable: Not connected
- UniFi switch trunk: Not connected

---

## Migration Steps Performed

### 1. WAN Interface Activation
**Issue:** wan1.847 was configured but status set to DOWN
**Resolution:**
```bash
config system interface
    edit "wan1.847"
        unset status
    next
end
```
**Result:** Interface came UP, link established at 1000Mbps

### 2. Internal Network Activation
**Issue:** "internal" hard-switch interface was administratively DOWN
**Steps:**
1. Connected UniFi switch trunk cable to FortiGate internal5 port
2. Enabled internal hard-switch interface:
```bash
config system interface
    edit "internal"
        unset status
    next
end
```
**Result:** Link established, all VLANs became operational

### 3. ISP Monitoring Configuration
**Requirement:** Allow ICMP from ISP monitoring network (204.186.63.0/26)
**Configuration:**
```bash
# Created firewall address object
config firewall address
    edit "ISP-Network-204.186.63.0"
        set subnet 204.186.63.0 255.255.255.192
        set comment "ISP ICMP monitoring subnet"
    next
end

# Created firewall policy (manually via console)
config firewall policy
    edit 0
        set name "Allow-ICMP-to-ISP-Network"
        set srcintf "internal1.4" "internal1.3" "internal1.5" "internal1.6" "dmz"
        set dstintf "wan1.847"
        set srcaddr "all"
        set dstaddr "ISP-Network-204.186.63.0"
        set action accept
        set schedule "always"
        set service "PING"
        set nat enable
        set comments "Allow ICMP to ISP monitoring network"
    next
end
```

### 4. Verification Testing
**Tests Performed:**
- ✅ FortiGate ping to 8.8.8.8 - SUCCESS
- ✅ FortiGate ping to google.com - SUCCESS
- ✅ Workstation internet access from all VLANs - SUCCESS
- ✅ DHCP address assignment on all VLANs - SUCCESS
- ✅ VLAN isolation (inter-VLAN blocking) - SUCCESS

---

## Post-Migration Configuration

### WAN Interface Status
```
Interface: wan1.847
Status: UP
Speed: 1000Mbps Full Duplex
IP Address: 204.186.251.250/30
Gateway: 204.186.251.249
MAC Address: 48:3a:02:57:b5:b8
VLAN ID: 847
```

### Internal Network Status
```
Interface: internal (hard-switch)
Status: UP
Active Port: internal5
Connected To: UniFi switch trunk
VLANs Trunked: 3, 4, 5, 6
```

### VLAN Status - All Operational
| VLAN | Network | Gateway | DHCP Pool | Status |
|------|---------|---------|-----------|--------|
| 3 | 172.16.3.0/24 | 172.16.3.1 | 100-200 | ✅ UP |
| 4 | 172.16.4.0/24 | 172.16.4.1 | 100-200 | ✅ UP |
| 5 | 172.16.5.0/24 | 172.16.5.1 | 100-200 | ✅ UP |
| 6 | 172.16.6.0/24 | 172.16.6.1 | 100-200 | ✅ UP |

### Firewall Policies (Active)
- Policy 11: Management → Internet (wan1.847)
- Policy 12: Studio-LAN → Internet (wan1.847)
- Policy 13: IoT → Internet (wan1.847)
- Policy 14: Guest → Internet (wan1.847)
- Policy 15: CORP-LAN → Internet (wan1.847)
- Policy 16: All VLANs → ISP Monitoring Network (ICMP)

---

## Issues Encountered & Resolutions

### Issue 1: WAN Interface Down
**Symptom:** wan1.847 configured but no link
**Root Cause:** Interface administratively disabled (set status down)
**Resolution:** Removed status down setting with `unset status`
**Time to Resolve:** < 2 minutes

### Issue 2: Internal VLANs Not Working
**Symptom:** No internet access from workstations, DHCP not working
**Root Cause:** "internal" hard-switch interface administratively disabled
**Resolution:** Enabled interface with `unset status`
**Time to Resolve:** < 2 minutes

### Issue 3: ISP Cannot Ping WAN IP
**Symptom:** ISP monitoring unable to ping 204.186.251.250
**Root Cause:** Unknown - policy created, allowaccess ping enabled
**Status:** ⚠️ OPEN - Does not affect internet connectivity
**Next Steps:** Additional troubleshooting or coordinate with ISP

---

## Verification Results

### ✅ Internet Connectivity
- FortiGate can reach external IPs (8.8.8.8, google.com)
- All workstations have internet access
- DNS resolution working
- NAT functioning properly

### ✅ DHCP Services
- All VLANs serving DHCP addresses
- Clients receiving correct IP ranges (x.x.x.100-200)
- DNS servers configured (1.1.1.1, 8.8.8.8)
- Default gateways assigned correctly

### ✅ Security Posture
- VLAN isolation enforced (inter-VLAN traffic blocked)
- All traffic logged via firewall policies
- FIPS-CC mode active
- NAT enabled on all outbound policies

### ✅ Management Access
- GUI accessible via https://172.16.4.1 (CORP-LAN)
- SSH accessible from CORP network
- Console access via COM3 verified

---

## Performance Metrics

### WAN Interface
- Link Speed: 1000Mbps Full Duplex
- Packets Received: 4516+ (at time of testing)
- Packets Transmitted: Minimal during testing
- No errors or drops detected

### Internal Interface
- Link Speed: Varies by device
- Status: UP and forwarding
- VLAN tagging: Working correctly
- No errors detected

---

## Outstanding Items

### Critical (None)
All critical migration items complete.

### Non-Critical
1. **ISP Monitoring Ping Issue**
   - Impact: Low (monitoring only)
   - Status: Open
   - Action: Further troubleshooting if ISP requires

2. **Configuration Backup**
   - Recommendation: Create post-migration backup
   - Command: `execute backup config management-station "post-migration-backup-20251211"`

3. **DMZ Interface**
   - Status: Configured but not in use
   - Action: Determine future use case or repurpose

---

## CMMC Compliance Status

### ✅ Implemented
- FIPS-CC cryptography enabled
- Strong password policy (15+ chars, complexity, 90-day expiry)
- Admin timeouts and lockouts
- Login banners
- Traffic logging
- VLAN segmentation
- Secure protocols only (TLS 1.2+, SSH v2)

### ⚠️ Pending
- Centralized logging (syslog/FortiAnalyzer)
- Individual admin accounts (currently using shared admin)
- Multi-factor authentication
- Automated configuration backups
- System security plan documentation

---

## Rollback Capability

**SonicWall Status:** Decommissioned/standby
**Rollback Time:** < 5 minutes (disconnect FortiGate, reconnect SonicWall)
**Rollback Trigger:** Critical business application failure (none encountered)

---

## Next Steps

### Immediate (Today)
- [x] Verify all users have internet access - COMPLETE
- [x] Monitor for issues during business hours - ONGOING
- [ ] Create configuration backup
- [ ] Document any user-reported issues

### Short Term (This Week)
- [ ] Continue monitoring stability
- [ ] Troubleshoot ISP ping issue (if required)
- [ ] Plan for CMMC compliance items

### Medium Term (Next 1-2 Weeks)
- [ ] Set up centralized logging
- [ ] Create individual admin accounts
- [ ] Configure MFA for admin access
- [ ] Implement automated backups
- [ ] Update system security plan

---

## Lessons Learned

1. **Check Administrative Status:** Both wan1.847 and internal interfaces were configured correctly but administratively disabled. Always verify `status` setting when troubleshooting "down" interfaces.

2. **Serial Console Challenges:** Automated scripts struggled with CLI timeouts and login banners. Manual commands via PuTTY were more efficient for complex configurations.

3. **Interface Dependencies:** VLAN sub-interfaces depend on parent interface status. When troubleshooting VLANs, check both the VLAN interface and the parent/hard-switch interface.

4. **Testing Sequence:** Always test from the firewall first (execute ping) before troubleshooting client connectivity. This quickly isolates whether the issue is WAN-side or LAN-side.

---

## Support Information

### Device Details
- **Model:** FortiGate 60F
- **Serial:** FGT60FTK24031122
- **Firmware:** FortiOS 7.4.9 build2829 (GA.M)
- **FIPS-CC:** Enabled (irreversible)

### Key IP Addresses
- **WAN IP:** 204.186.251.250/30
- **WAN Gateway:** 204.186.251.249
- **WAN MAC:** 48:3a:02:57:b5:b8
- **CORP Gateway:** 172.16.4.1
- **Management:** https://172.16.4.1

### Support Contacts
- **Fortinet Support:** 1-866-648-4638
- **Support Portal:** https://support.fortinet.com

---

## Sign-Off

**Migration Status:** ✅ SUCCESSFUL
**Internet Connectivity:** ✅ OPERATIONAL
**All VLANs:** ✅ OPERATIONAL
**User Impact:** ✅ MINIMAL
**Business Continuity:** ✅ MAINTAINED

**Migration Completed By:** Claude Code
**Date:** December 11, 2025
**Time:** Evening (specific time not logged)

---

**🎉 Migration Complete - FortiGate 60F now serving as production firewall with CMMC Level 2 security controls!**
