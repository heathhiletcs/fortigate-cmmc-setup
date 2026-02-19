# FortiGate 60F - TODO List

**Last Updated:** February 18, 2026
**Status:** Production — operational and running

---

## Completed

- [x] Configure Production WAN (wan1.847) - December 2025
- [x] Resolve CORP-LAN subnet conflict - December 2025
- [x] Physical connections (fiber to wan1, UniFi trunk to internal5) - December 2025
- [x] Management access via CORP-LAN (172.16.4.1) - December 2025
- [x] SonicWall cutover - December 2025
- [x] Post-migration validation - all VLANs operational
- [x] Native VLAN fix (192.168.168.168/24 on `internal` for UniFi mgmt) - January 2026
- [x] VLAN 3 DHCP fix (disabled vci-match on DHCP server 2) - February 2026
- [x] Hardened WAN interface (removed https/ssh from wan1.847, ping only) - February 2026
- [x] ISP monitoring diagnosed — waiting on ISP to fix routing from 204.186.63.0/26
- [x] Fixed DNS (was DoT with mismatched hostname, switched to cleartext) - February 2026
- [x] FortiGuard connected and definitions updating - February 2026
- [x] NTP configured via FortiGuard servers - February 2026
- [x] FortiGate Cloud activated (free tier, US region) - February 2026

---

## ✅ COMPLETED - FortiGate Configuration

### Network Configuration (Matches SonicWall)
| FortiGate Interface | IP Address | Purpose | Status |
|---------------------|------------|---------|--------|
| internal (untagged) | 192.168.168.168/24 | Default LAN / UniFi Management | Done |
| internal.3 (VLAN 3) | 172.16.3.1/24 | IoT Network | Done |
| internal.4 (VLAN 4) | 172.16.4.1/24 | CORP-LAN | Done |
| internal.5 (VLAN 5) | 172.16.5.1/24 | Studio-LAN | Done |
| internal.6 (VLAN 6) | 172.16.6.1/24 | Guest Network | Done |
| wan1.847 | 204.186.251.250/30 | Fiber WAN | Done |

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
- [x] Management-to-Internet (internal -> wan1.847)
- [x] IoT-to-Internet (internal.3 -> wan1.847)
- [x] CORP-to-Internet (internal.4 -> wan1.847)
- [x] Studio-to-Internet (internal.5 -> wan1.847)
- [x] Guest-to-Internet (internal.6 -> wan1.847)

**UniFi CloudKey Management (Policies 10-17):**
- [x] CloudKey (192.168.168.30) -> IoT, CORP, Studio, Guest
- [x] All VLANs -> CloudKey (for device inform)
- [x] Custom UniFi-Management service group (ports 8080, 8443, 8880, 8843, 6789, 3478/udp, 10001/udp)

**Inter-VLAN Isolation (Policies 100-104):**
- [x] DENY IoT -> all other networks
- [x] DENY CORP -> all other networks
- [x] DENY Studio -> all other networks
- [x] DENY Guest -> all other networks
- [x] DENY Management -> all VLANs (except CloudKey allowed above)
- [x] Logging enabled on all deny policies

### Routing
- [x] Default route via 204.186.251.249 (wan1.847)
- [x] DNS: 8.8.8.8, 8.8.4.4 (cleartext)

---

## Medium Priority - CMMC Compliance Requirements

### 1. Centralized Logging (CMMC 3.3.1, 3.3.2)
- [x] FortiGate Cloud free tier activated (7-day retention)
- [ ] Upgrade to paid FortiGate Cloud (1-year retention) OR set up syslog/FortiAnalyzer for 90+ day retention
- [ ] Verify logs are being received and retained
- [ ] Set up log review procedures

### 2. Individual Admin Accounts (CMMC 3.1.1)
- [ ] Create individual admin accounts (no shared admin account)
- [ ] Disable or rename default "admin" account
- [ ] Document who has admin access
- [ ] Implement least privilege (use restricted profiles where appropriate)

### 3. Multi-Factor Authentication (CMMC 3.5.3)
- [ ] Decide on MFA solution (FortiToken, RADIUS, or Azure AD)
- [ ] Configure MFA for admin access
- [ ] Test MFA login
- [ ] Document MFA procedures for admins

### 4. Configuration Backups (CMMC 3.9.1)
- [ ] Set up automated configuration backups
- [ ] Store backups securely off-device
- [ ] Test configuration restore procedure
- [ ] Document backup schedule and retention

### 5. NTP Configuration (CMMC 3.3.7) - DONE
- [x] Configured NTP via FortiGuard servers
- [x] Verified time synchronization (4 servers reachable)
- [x] Documented NTP sources (ntp1/ntp2.fortiguard.com)

### 6. System Security Plan Documentation
- [ ] Document network topology
- [ ] Document security controls implemented
- [ ] Create data flow diagrams
- [ ] Document access control procedures
- [ ] Create incident response procedures
- [ ] Document backup and recovery procedures
- [ ] Prepare for C3PAO assessment

---

## Low Priority - Enhancements

### 7. Firmware Upgrade — DONE
- [x] Upgraded from 7.4.9 to 7.4.11 build2878 (Mature) — patches CVE-2026-24858

### 8. VPN Configuration — IKEv2 + EAP with Azure AD SAML (BLOCKED)
See VPN-SETUP-STATUS.md for full implementation guide and troubleshooting.

**Phase 1: Azure AD** — DONE
- [x] Reconfigure enterprise app SAML URLs to use `remote.thecoresolution.com`
- [x] Verify SAML claims (username, group) and user assignment
- [x] Verify Conditional Access policy (MFA enforced)

**Phase 2: Certificates (FIPS-CC)** — DONE (but may need revision)
- [x] SAML CA + signing cert created and imported (CA_Cert_1, REMOTE_Cert_1)
- [x] VPN CA + client cert created with SHA-256 (CA_Cert_3)
- [ ] May need: Server cert with CN=remote.thecoresolution.com for FortiGate
- [ ] May need: Client cert with EKU extensions (clientAuth, ipsecIKE)

**Phase 3: FortiGate SAML** — DONE
- [x] Configure SAML server (AzureAD-VPN) with correct URLs
- [x] Configure user group (VPN-Users-Azure)
- [x] Set auth-ike-saml-port 10443
- [x] Bind ike-saml-server to wan1.847
- [x] Set auth-cert (Fortinet_Factory)

**Phase 4: IPsec Tunnel** — DONE (config exists, tunnel won't come up)
- [x] Delete old IKEv1 CBS-VPN tunnel and policies
- [x] Create IKEv2 Phase 1 with EAP enabled
- [x] Create Phase 2 with AES256-SHA256
- [ ] Need to re-add `authusrgrp "VPN-Users-Azure"` (removed during debug)

**Phase 5: Firewall Policies** — DONE
- [x] Create VPN-to-Internet ALLOW policy
- [x] Create BLOCK-VPN-to-Internal DENY policy
- [x] Verify policy order (ALLOW above DENY)

**Phase 6: FortiClient** — BLOCKED
- [x] Install FortiClient 7.4.3 on test device
- [x] Create IKEv2 VPN profile with SSO enabled
- [x] SAML login works (Azure AD + MFA)
- [ ] **BLOCKED:** "gw validation failed" — tunnel does not establish

**Phase 7: Verification** — BLOCKED (waiting on Phase 6)
- [ ] Verify IP assignment from 10.255.1.x pool
- [ ] Verify internet access via VPN
- [ ] Verify internal networks are blocked

**Next steps to fix "gw validation failed":**
1. Generate FortiGate server cert with CN=remote.thecoresolution.com
2. Import VPN CA to Windows Trusted Root CA store
3. Re-add `authusrgrp "VPN-Users-Azure"` to phase1
4. Regenerate client cert with EKU extensions
5. Try `eap-cert-auth enable` on phase1
6. Evaluate FortiClient EMS if all else fails

### 9. Advanced Security Features
- [ ] Enable IPS (Intrusion Prevention System)
- [ ] Configure IPS sensors for critical VLANs
- [ ] Enable Application Control
- [ ] Configure Web Filtering
- [ ] Enable Antivirus scanning (if licensed)

---

## CMMC Assessment Preparation

### 10. C3PAO Assessment Readiness
- [ ] Review CMMC Level 2 requirements (110 practices)
- [ ] Complete System Security Plan (SSP)
- [ ] Document all security controls
- [ ] Prepare evidence of implementation:
  - Configuration exports
  - Log samples
  - Access control lists
  - Password policy screenshots
  - MFA configuration
  - Backup procedures
- [ ] Conduct internal assessment
- [ ] Remediate any gaps
- [ ] Schedule C3PAO assessment

---

## Quick Reference

### FortiGate Access
- **Console:** COM port, 9600 baud, 8N1
- **GUI:** https://192.168.168.168 (from management network)
- **GUI:** https://172.16.4.1 (from CORP network)
- **SSH:** ssh admin@172.16.4.1

### Common Commands
```bash
show system interface              # View all interfaces
show firewall policy               # View firewall policies
show system dhcp server            # View DHCP servers
get router info routing-table all  # View routing table
execute dhcp lease-list            # View DHCP leases
get system status                  # View system/FIPS status
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
