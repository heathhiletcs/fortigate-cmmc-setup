# FortiGate 60F - Production Deployment TODO List

## Critical Priority - VPN Authentication

### 0. Implement Azure AD Authentication for IPsec VPN
**Status:** ⚠️ BLOCKER - VPN tunnel configured but authentication method needs implementation

**Background:**
- IPsec VPN tunnel fully configured and operational (CBS-VPN)
- Phase 1 negotiation successful (IKEv1, Main Mode, AES256, SHA384, DH Group 15)
- Phase 2 configured with PFS enabled (AES256, SHA256, DH Group 15)
- Firewall policies created (VPN→Internet allowed, VPN→Internal blocked)
- **Issue:** IPsec XAUTH cannot use Azure AD SAML authentication directly

**Choose One Authentication Method:**

#### Option A: Azure MFA NPS Extension + RADIUS (Recommended)
**Cost:** Free (Microsoft-provided)
**Requirements:**
- Windows Server 2016+ (VM or physical)
- Network Policy Server (NPS) role
- Azure MFA NPS Extension

**Steps:**
- [ ] Provision Windows Server (evaluate existing servers or create VM)
- [ ] Install NPS role on Windows Server
- [ ] Download and install Azure MFA NPS Extension
- [ ] Configure NPS RADIUS server
  - Add FortiGate as RADIUS client
  - Configure connection request policy
  - Configure network policy for VPN-Users-Azure group
- [ ] Configure FortiGate RADIUS settings:
  ```bash
  config user radius
      edit "Azure-RADIUS"
          set server "<NPS-server-IP>"
          set secret "<shared-secret>"
          set auth-type auto
      next
  end

  config user group
      edit "VPN-Users-RADIUS"
          set member "Azure-RADIUS"
      next
  end

  config vpn ipsec phase1-interface
      edit "CBS-VPN"
          set authusrgrp "VPN-Users-RADIUS"
      next
  end
  ```
- [ ] Test VPN connection with Azure AD credentials
- [ ] Verify MFA enforcement
- [ ] Document RADIUS configuration for CMMC compliance

**Resources:**
- [Microsoft: Azure MFA NPS Extension Installation](https://learn.microsoft.com/en-us/azure/active-directory/authentication/howto-mfa-nps-extension)
- [FortiGate RADIUS Configuration](https://docs.fortinet.com/document/fortigate/7.4.0/administration-guide/891454/radius-servers)

#### Option B: FortiAuthenticator
**Cost:** Requires FortiAuthenticator license
**Requirements:**
- FortiAuthenticator VM or appliance
- FortiAuthenticator license

**Steps:**
- [ ] Acquire FortiAuthenticator license
- [ ] Deploy FortiAuthenticator VM
- [ ] Configure Azure AD SSO integration
- [ ] Configure RADIUS service
- [ ] Configure FortiGate to use FortiAuthenticator RADIUS
- [ ] Test VPN connection

#### Option C: Azure AD Domain Services
**Cost:** ~$110/month Azure subscription
**Requirements:**
- Azure AD DS enabled in Azure tenant
- Azure subscription with sufficient permissions

**Steps:**
- [ ] Enable Azure AD Domain Services in Azure portal
- [ ] Configure FortiGate LDAP settings
- [ ] Test VPN connection

**Decision Required By:** Next VPN configuration session
**Impact:** VPN cannot be deployed to users until authentication is implemented

---

## High Priority - Before Production Cutover

### 1. Configure Production WAN (VLAN 847)
- [ ] Configure wan1 as trunk interface (no IP)
- [ ] Create wan1.847 sub-interface
  - VLAN ID: 847
  - IP: 204.186.251.250/30
  - Gateway: 204.186.251.249
  - DNS: 8.8.8.8, 8.8.4.4
- [ ] Add default route via wan1.847
- [ ] Test internet connectivity through production WAN
- [ ] Update all firewall policies to use wan1.847 instead of wan1

**Commands:**
```bash
config system interface
    edit "wan1"
        set mode static
        set type physical
        set role wan
    next
    edit "wan1.847"
        set interface "wan1"
        set vlanid 847
        set mode static
        set ip 204.186.251.250 255.255.255.252
        set allowaccess ping
        set role wan
        set description "Fiber WAN VLAN 847"
    next
end

config router static
    edit 1
        set gateway 204.186.251.249
        set device "wan1.847"
    next
end

config system dns
    set primary 8.8.8.8
    set secondary 8.8.4.4
end

# Update firewall policies
config firewall policy
    edit 11
        set dstintf "wan1.847"
    next
    edit 12
        set dstintf "wan1.847"
    next
    edit 13
        set dstintf "wan1.847"
    next
    edit 14
        set dstintf "wan1.847"
    next
end
```

### 2. Resolve CORP-LAN Subnet Conflict
Once production WAN is on 204.186.251.0/30 subnet:
- [ ] Enable internal1.4 interface
  ```bash
  config system interface
      edit "internal1.4"
          set status up
      next
  end
  ```
- [ ] Create firewall policy for CORP-LAN to Internet
  ```bash
  config firewall policy
      edit 15
          set name "CORP-to-Internet"
          set status enable
          set srcintf "internal1.4"
          set dstintf "wan1.847"
          set action accept
          set srcaddr "all"
          set dstaddr "all"
          set schedule "always"
          set service "ALL"
          set nat enable
          set logtraffic all
          set comments "CMMC L2: Corporate network"
      next
  end
  ```
- [ ] Test CORP-LAN connectivity

### 3. Physical Connections
- [ ] Connect fiber/ISP to wan1 port
- [ ] Connect UniFi switch trunk to internal1 (or any internal port)
- [ ] Verify VLAN tags are passing correctly from UniFi switch
- [ ] Test connectivity on all VLANs (3, 4, 5, 6)

### 4. Reconfigure Management Access
- [ ] Decide permanent management strategy:
  - Option A: Keep DMZ for management
  - Option B: Use CORP-LAN (internal1.4) for management
  - Option C: Dedicated management VLAN
- [ ] Remove temporary management DHCP from DMZ if not using it
- [ ] Update admin access controls on chosen management interface

## Medium Priority - CMMC Compliance Requirements

### 5. Centralized Logging (CMMC 3.3.1, 3.3.2)
- [ ] Set up syslog server OR FortiAnalyzer
- [ ] Configure FortiGate to send logs to centralized server
  ```bash
  config log syslogd setting
      set status enable
      set server "<syslog-server-ip>"
      set port 514
      set facility local7
      set source-ip "<fortigate-management-ip>"
      set format default
  end
  ```
- [ ] Verify logs are being received
- [ ] Configure log retention (CMMC requires 90+ days)
- [ ] Set up log review procedures

### 6. Individual Admin Accounts (CMMC 3.1.1)
- [ ] Create individual admin accounts (no shared admin account)
  ```bash
  config system admin
      edit "john.doe"
          set accprofile "super_admin"
          set vdom "root"
          set password "<15+char-password>"
      next
      edit "jane.smith"
          set accprofile "super_admin"
          set vdom "root"
          set password "<15+char-password>"
      next
  end
  ```
- [ ] Disable or rename default "admin" account
- [ ] Document who has admin access
- [ ] Implement least privilege (use restricted profiles where appropriate)

### 7. Multi-Factor Authentication (CMMC 3.5.3)
- [ ] Decide on MFA solution:
  - FortiToken (hardware or mobile)
  - RADIUS with MFA
  - TACACS+ with MFA
- [ ] Configure MFA for admin access
  ```bash
  config system global
      set multi-factor-authentication required
  end
  ```
- [ ] Test MFA login
- [ ] Document MFA procedures for admins

### 8. Configuration Backups (CMMC 3.9.1)
- [ ] Set up automated configuration backups
- [ ] Store backups securely off-device
- [ ] Test configuration restore procedure
- [ ] Document backup schedule and retention

**Manual Backup:**
```bash
execute backup config management-station "daily-backup-YYYYMMDD"
```

**Or configure auto-backup via GUI:**
- System > Configuration > Backup
- Enable automatic backup to FTP/TFTP/USB

### 9. System Security Plan Documentation
- [ ] Document network topology
- [ ] Document security controls implemented
- [ ] Create data flow diagrams
- [ ] Document access control procedures
- [ ] Create incident response procedures
- [ ] Document backup and recovery procedures
- [ ] Prepare for C3PAO assessment

## Low Priority - Nice to Have

### 10. Additional VLAN Configuration
If needed for additional networks from SonicWall:
- [ ] Create VLAN 1449 (if still needed)
  - IP from SonicWall: 204.186.249.142/29
- [ ] Create any additional VLANs
- [ ] Configure firewall policies for new VLANs

### 11. Advanced Security Features
- [ ] Enable IPS (Intrusion Prevention System)
  ```bash
  config ips global
      set fail-open disable
      set database regular
  end
  ```
- [ ] Configure IPS sensors for critical VLANs
- [ ] Enable Application Control
- [ ] Configure Web Filtering
- [ ] Enable Antivirus scanning (if licensed)
- [ ] Configure SSL inspection (if needed and licensed)

### 12. High Availability (Optional)
If you have a second FortiGate 60F:
- [ ] Configure HA cluster
- [ ] Set up heartbeat interfaces
- [ ] Test failover scenarios
- [ ] Document HA procedures

### 13. VPN Configuration (If Needed)
- [ ] Configure IPsec VPN for remote sites
- [ ] Configure SSL VPN for remote users
- [ ] Apply CMMC-compliant settings to VPN
  - Strong encryption (AES-256)
  - Perfect Forward Secrecy
  - User authentication with MFA
  - Traffic logging

### 14. DNS Configuration
- [ ] Consider internal DNS server
- [ ] Configure DNS security features
- [ ] Set up DNS filtering if needed

### 15. NTP Configuration (CMMC 3.3.7)
- [ ] Configure NTP servers for accurate time
  ```bash
  config system ntp
      set ntpsync enable
      set type fortiguard
  end
  ```
- [ ] Verify time synchronization
- [ ] Document NTP sources

## Testing & Validation

### 16. Comprehensive Testing
- [ ] Test internet access from all VLANs
- [ ] Verify VLAN isolation (devices in different VLANs can't communicate)
- [ ] Test DHCP on all VLANs
- [ ] Verify DNS resolution
- [ ] Test firewall policies
- [ ] Verify logging is working
- [ ] Test admin lockout (intentionally fail 3+ logins)
- [ ] Test password policy enforcement
- [ ] Verify session timeouts work correctly
- [ ] Test GUI access over HTTPS
- [ ] Verify SSH access (not telnet)

### 17. Performance Baseline
- [ ] Document baseline throughput
- [ ] Monitor CPU usage under normal load
- [ ] Monitor memory usage
- [ ] Verify no packet drops
- [ ] Test latency across VLANs

### 18. Disaster Recovery Testing
- [ ] Test configuration restore from backup
- [ ] Document recovery time objective (RTO)
- [ ] Create disaster recovery runbook
- [ ] Test failover procedures (if HA configured)

## Maintenance & Operations

### 19. Regular Maintenance Tasks
- [ ] Schedule firmware updates (test in lab first)
- [ ] Schedule signature updates (IPS, AV, App Control)
- [ ] Review logs regularly
- [ ] Review firewall policies quarterly
- [ ] Audit admin accounts quarterly
- [ ] Test backups monthly
- [ ] Update documentation as changes are made

### 20. Monitoring & Alerting
- [ ] Set up monitoring solution
- [ ] Configure alerts for:
  - High CPU usage
  - High memory usage
  - Interface down
  - Failed login attempts
  - Policy violations
  - VPN tunnels down
- [ ] Document incident response procedures

## Migration Tasks

### 21. Cutover from SonicWall
- [ ] Document current SonicWall configuration
- [ ] Create detailed migration plan
- [ ] Schedule maintenance window
- [ ] Notify users of planned downtime
- [ ] Perform cutover:
  1. Backup SonicWall configuration
  2. Backup FortiGate configuration
  3. Disconnect SonicWall from network
  4. Connect FortiGate to production network
  5. Verify all VLANs working
  6. Test internet connectivity
  7. Monitor for issues
- [ ] Keep SonicWall available for quick rollback if needed
- [ ] Document lessons learned

### 22. Post-Migration Validation
- [ ] Verify all VLANs operational
- [ ] Confirm DHCP working on all networks
- [ ] Test internet access from each VLAN
- [ ] Verify Inter-VLAN isolation
- [ ] Check all firewall policies active
- [ ] Confirm logging working
- [ ] User acceptance testing
- [ ] Monitor for 24-48 hours for issues

## CMMC Assessment Preparation

### 23. C3PAO Assessment Readiness
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

## Quick Reference Commands

**View all interfaces:**
```bash
show system interface
```

**View firewall policies:**
```bash
show firewall policy
```

**View DHCP servers:**
```bash
show system dhcp server
```

**View routing table:**
```bash
get router info routing-table all
```

**Backup configuration:**
```bash
execute backup config management-station "backup-YYYYMMDD"
```

**View FIPS status:**
```bash
get system status | grep FIPS
```

**View sessions:**
```bash
get system session list
```

**View DHCP leases:**
```bash
execute dhcp lease-list
```

---

**Priority Legend:**
- High Priority: Required for production operation
- Medium Priority: Required for CMMC compliance
- Low Priority: Nice to have or future enhancements

**Estimated Timeline:**
- High Priority tasks: 1-2 days
- Medium Priority tasks: 1-2 weeks
- Low Priority tasks: Ongoing

---
*Last Updated: November 2025*
*Status: Test configuration complete, ready for production deployment*
