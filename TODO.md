# FortiGate 60F - Production Deployment TODO List

**Last Updated:** February 4, 2026
**Status:** ✅ Configuration complete, ready for production cutover

---

## ✅ COMPLETED - FortiGate Configuration

### Network Configuration (Matches SonicWall)
| FortiGate Interface | IP Address | Purpose | Status |
|---------------------|------------|---------|--------|
| internal (untagged) | 192.168.168.168/24 | Default LAN / UniFi Management | ✅ Done |
| internal.3 (VLAN 3) | 172.16.3.1/24 | IoT Network | ✅ Done |
| internal.4 (VLAN 4) | 172.16.4.1/24 | CORP-LAN | ✅ Done |
| internal.5 (VLAN 5) | 172.16.5.1/24 | Studio-LAN | ✅ Done |
| internal.6 (VLAN 6) | 172.16.6.1/24 | Guest Network | ✅ Done |
| wan1.847 | 204.186.251.250/30 | Fiber WAN | ✅ Done |

### CMMC Level 2 Security Settings
- [x] FIPS-CC mode enabled
- [x] Pre-login warning banner
- [x] Post-login warning banner
- [x] Admin lockout after 3 failed attempts (5 min lockout)
- [x] Admin session timeout (15 min)
- [x] TLS 1.2/1.3 only for HTTPS
- [x] Telnet disabled
- [x] Hostname set (CBS-FORTI)

### DHCP Servers
- [x] internal (192.168.168.100-200)
- [x] internal.3 / IoT (172.16.3.100-200)
- [x] internal.4 / CORP (172.16.4.100-200)
- [x] internal.5 / Studio (172.16.5.100-200)
- [x] internal.6 / Guest (172.16.6.100-200)

### Firewall Policies
**Internet Access (Policies 1-5):**
- [x] Management-to-Internet (internal → wan1.847)
- [x] IoT-to-Internet (internal.3 → wan1.847)
- [x] CORP-to-Internet (internal.4 → wan1.847)
- [x] Studio-to-Internet (internal.5 → wan1.847)
- [x] Guest-to-Internet (internal.6 → wan1.847)

**UniFi CloudKey Management (Policies 10-17):**
- [x] CloudKey (192.168.168.30) → IoT, CORP, Studio, Guest
- [x] All VLANs → CloudKey (for device inform)
- [x] Custom UniFi-Management service group (ports 8080, 8443, 8880, 8843, 6789, 3478/udp, 10001/udp)

**Inter-VLAN Isolation (Policies 100-104):**
- [x] DENY IoT → all other networks
- [x] DENY CORP → all other networks
- [x] DENY Studio → all other networks
- [x] DENY Guest → all other networks
- [x] DENY Management → all VLANs (except CloudKey allowed above)
- [x] Logging enabled on all deny policies

### Routing
- [x] Default route via 204.186.251.249 (wan1.847)
- [x] DNS: 8.8.8.8, 8.8.4.4

---

## 🔄 CUTOVER PLAN - SonicWall to FortiGate

### Pre-Cutover Checklist
- [ ] Schedule maintenance window (recommend off-hours)
- [ ] Notify users of planned downtime
- [ ] Backup SonicWall configuration
- [ ] Backup FortiGate configuration (`execute backup config flash`)
- [ ] Have SonicWall ready for quick rollback if needed
- [ ] Test console/serial access to FortiGate

### Physical Connections Required
```
ISP Fiber ──────► wan1 port (VLAN 847 tagged)
UniFi Core Switch ──────► any internal port (1-5)
                          └── Untagged: 192.168.168.x
                          └── VLAN 3: 172.16.3.x (IoT)
                          └── VLAN 4: 172.16.4.x (CORP)
                          └── VLAN 5: 172.16.5.x (Studio)
                          └── VLAN 6: 172.16.6.x (Guest)
```

### Cutover Steps
1. [ ] **Backup SonicWall** - Export current configuration
2. [ ] **Power down SonicWall** - Disconnect from network
3. [ ] **Connect FortiGate WAN** - Fiber/ISP to wan1 port
4. [ ] **Connect FortiGate LAN** - UniFi switch trunk to any internal port (1-5)
5. [ ] **Verify link lights** - wan1 and internal port should show link
6. [ ] **Test from management network** (192.168.168.x):
   - [ ] Ping 192.168.168.168 (FortiGate)
   - [ ] Ping 8.8.8.8 (internet)
   - [ ] Browse to https://192.168.168.168 (FortiGate GUI)
7. [ ] **Test from each VLAN:**
   - [ ] IoT (172.16.3.x) - ping gateway, ping internet
   - [ ] CORP (172.16.4.x) - ping gateway, ping internet
   - [ ] Studio (172.16.5.x) - ping gateway, ping internet
   - [ ] Guest (172.16.6.x) - ping gateway, ping internet
8. [ ] **Test UniFi CloudKey:**
   - [ ] CloudKey can reach UniFi devices on all VLANs
   - [ ] UniFi devices show as connected in controller
9. [ ] **Verify VLAN isolation:**
   - [ ] CORP cannot ping IoT
   - [ ] Guest cannot ping CORP
   - [ ] etc.

### Rollback Plan
If issues occur:
1. Disconnect FortiGate
2. Reconnect SonicWall
3. Power on SonicWall
4. Verify connectivity restored
5. Troubleshoot FortiGate offline

---

## ⚠️ POST-CUTOVER - Still Required

### VPN Configuration (Not migrated yet)
**Status:** VPN was configured on old FortiGate config but needs to be re-added after cutover verification

- [ ] Configure CBS-VPN IPsec tunnel
- [ ] Configure VPN IP pool (10.255.1.0/24)
- [ ] Configure VPN firewall policies
- [ ] Choose authentication method:
  - Option A: Azure MFA NPS Extension + RADIUS (Recommended)
  - Option B: FortiAuthenticator
  - Option C: Azure AD Domain Services
- [ ] Test VPN connectivity

### CMMC Compliance Items (Medium Priority)

#### Centralized Logging (CMMC 3.3.1, 3.3.2)
- [ ] Set up syslog server OR FortiAnalyzer
- [ ] Configure FortiGate to send logs
- [ ] Verify log retention (90+ days required)

#### Individual Admin Accounts (CMMC 3.1.1)
- [ ] Create individual admin accounts
- [ ] Disable/rename default "admin" account
- [ ] Document admin access

#### Multi-Factor Authentication (CMMC 3.5.3)
- [ ] Configure MFA for admin access
- [ ] Test MFA login

#### Configuration Backups (CMMC 3.9.1)
- [ ] Set up automated backups
- [ ] Test restore procedure

### Documentation
- [ ] Update network topology diagram
- [ ] Document security controls for SSP
- [ ] Create admin procedures document
- [ ] Update incident response procedures

---

## Quick Reference

### FortiGate Access
- **Console:** COM port, 9600 baud, 8N1
- **GUI:** https://192.168.168.168 (from management network)
- **GUI:** https://172.16.4.1 (from CORP network)
- **SSH:** ssh admin@192.168.168.168

### Common Commands
```bash
# View interfaces
get system interface

# View firewall policies
show firewall policy

# View DHCP leases
execute dhcp lease-list

# View routing table
get router info routing-table all

# Backup config
execute backup config flash

# View active sessions
get system session list
```

### SonicWall to FortiGate Interface Mapping
| SonicWall | FortiGate | IP Address |
|-----------|-----------|------------|
| X0 | internal | 192.168.168.168/24 |
| X0:V3 | internal.3 | 172.16.3.1/24 |
| X0:V4 | internal.4 | 172.16.4.1/24 |
| X0:V5 | internal.5 | 172.16.5.1/24 |
| X0:V6 | internal.6 | 172.16.6.1/24 |
| X1:V847 | wan1.847 | 204.186.251.250/30 |

---

*Configuration completed: February 4, 2026*
*Ready for production cutover*
