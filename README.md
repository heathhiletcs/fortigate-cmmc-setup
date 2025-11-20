# FortiGate 60F - CMMC Level 2 Configuration

## Overview

This repository contains complete configuration documentation for a FortiGate 60F firewall configured for **CMMC (Cybersecurity Maturity Model Certification) Level 2** compliance. The firewall is configured with FIPS-CC mode enabled and implements NIST 800-171 security controls required for DoD contractors handling CUI (Controlled Unclassified Information).

## Device Information

- **Model:** FortiGate 60F
- **Serial:** FGT60FTK24031122
- **Firmware:** FortiOS 7.4.9 build2829 (GA.M)
- **Security Mode:** FIPS-CC Enabled (FIPS 140-2 validated cryptography)
- **Hostname:** CBS-FORTI

## Current Status

**Configuration:** ✅ Complete
**CMMC Level 2:** ✅ Core requirements implemented
**Deployment Status:** 📦 Ready for physical connection
**Next Phase:** Cable connections and internet verification

## Documentation

### 📋 [DEPLOYMENT-READY.md](DEPLOYMENT-READY.md)
**Start here for deployment.** Step-by-step guide for connecting cables, verifying connectivity, and production cutover. Includes rollback plan and emergency information.

### 📖 [CONTEXT.md](CONTEXT.md)
Complete technical reference with all interface configurations, VLAN settings, firewall policies, DHCP servers, and CMMC compliance settings.

### ✅ [TODO.md](TODO.md)
Comprehensive task list organized by priority:
- High: Production deployment tasks
- Medium: CMMC compliance finalization
- Low: Advanced features and enhancements

### 📝 [SESSION-NOTES.md](SESSION-NOTES.md)
Detailed session context for continuity - includes all configuration decisions, issues encountered, and next session preparation.

## Network Configuration

### VLANs Configured
- **VLAN 3:** 172.16.3.0/24 - IoT Guest Network
- **VLAN 4:** 172.16.4.0/24 - CORP-LAN (Corporate)
- **VLAN 5:** 172.16.5.0/24 - Studio-LAN
- **VLAN 6:** 172.16.6.0/24 - Guest Network

### WAN Configuration
- **Interface:** wan1.847 (VLAN 847)
- **IP:** 204.186.251.250/30
- **Gateway:** 204.186.251.249

### Security Features
- FIPS 140-2 validated cryptography (FIPS-CC mode)
- 15+ character password policy with complexity
- Admin lockout after 3 failed attempts
- 15-minute admin timeout
- TLS 1.2+ only, SSH v2 only
- All traffic logged
- VLAN isolation (no inter-VLAN communication)

## CMMC Level 2 Compliance

### Implemented Controls
✅ Access Control (3.1.x)
✅ Password Policy (3.5.7)
✅ Session Management (3.1.11)
✅ Cryptographic Protection (3.13.11)
✅ Network Segmentation (3.13.1)
✅ Audit Logging (3.3.x)

### Pending for Full Compliance
- Centralized logging (syslog/FortiAnalyzer)
- Individual admin accounts (no shared admin)
- Multi-factor authentication
- Automated configuration backups
- System Security Plan documentation

## Deployment Timeline

### Phase 1: Physical Deployment (Day 1)
1. Connect fiber to wan1 port
2. Connect UniFi switch to internal port
3. Verify internet connectivity
4. Test all VLANs

### Phase 2: VPN Configuration (Week 1)
1. Configure SSL VPN portal
2. Set up Azure AD SAML authentication (VPN users)
3. Configure Azure AD SAML for admin access
4. Test FortiClient VPN
5. Verify full tunnel operation

### Phase 3: CMMC Finalization (Week 1-2)
1. Set up centralized logging
2. Create individual admin accounts
3. Enable MFA
4. Configure automated backups
5. Complete System Security Plan

## Management Access

- **GUI:** https://172.16.4.1 (from CORP network)
- **SSH:** ssh admin@172.16.4.1 (from CORP network)
- **Console:** USB-C, 9600 baud, 8N1

## Support Resources

- **Fortinet Support:** https://support.fortinet.com
- **Phone:** 1-866-648-4638
- **Documentation:** FortiOS 7.4.9 Administration Guide
- **CMMC Resources:** https://www.acq.osd.mil/cmmc/

## Migration Notes

This FortiGate replaces a SonicWall firewall. All VLANs previously configured on the SonicWall have been migrated and are ready for operation on the existing UniFi switching infrastructure.

---

**Last Updated:** November 2025
**Configuration Status:** Complete and ready for deployment
**CMMC Level 2:** Core requirements implemented, pending final items
