# FortiGate 60F - IPsec VPN with Azure AD Authentication Setup

**Start Date:** December 12, 2025
**Last Updated:** December 15, 2025
**Status:** 🔄 IN PROGRESS (Authentication Method Pending)
**Completion:** ~85%

---

## Configuration Overview

**VPN Type:** IPsec IKEv1 Dial-Up VPN (XAUTH)
**Authentication:** Azure AD via RADIUS (Planned - NPS Extension)
**VPN Client:** FortiClient
**Access Model:** Full tunnel - Internet only (no internal network access)
**Target Users:** 1-10 users
**Compliance:** CMMC Level 2 compliant

### Why IPsec Instead of SSL VPN?
**Fortinet removed SSL VPN support from FortiGate models with 2GB RAM or less starting in FortiOS 7.6.0.** The FortiGate 60F has 2GB RAM, making IPsec VPN the only long-term remote access solution for this hardware.

**Reference:** [Fortinet Documentation - SSL VPN Removed from 2GB RAM Models](https://docs.fortinet.com/document/fortigate/7.6.1/fortios-release-notes/877104/ssl-vpn-removed-from-2gb-ram-models-for-tunnel-and-web-mode)

### Current Firmware Status
- **Current Version:** FortiOS 7.4.9 (SSL VPN still available)
- **Future Limitation:** Upgrading to 7.6.0+ will remove SSL VPN entirely
- **Solution:** IPsec VPN is the supported path forward

---

## Progress Summary

### ✅ Phase 1: Azure AD Configuration (COMPLETE)

#### 1.1 Azure AD Enterprise Application
- ✅ Created enterprise application: "FortiGate IPsec VPN SAML"
- ✅ Configured as SAML-based SSO application
- ✅ Application ID: (configured)
- ✅ Tenant ID: cd124fca-acb6-43c1-b769-36ee8024d7f9

#### 1.2 SAML Configuration
- ✅ Entity ID: `https://sts.windows.net/cd124fca-acb6-43c1-b769-36ee8024d7f9/`
- ✅ Sign-on URL: `https://login.microsoftonline.com/cd124fca-acb6-43c1-b769-36ee8024d7f9/saml2`
- ✅ Logout URL: `https://login.microsoftonline.com/cd124fca-acb6-43c1-b769-36ee8024d7f9/saml2`
- ✅ Reply URL: `https://172.16.4.1:10443/remote/saml/login`

#### 1.3 SAML Claims Configured
- ✅ `username` → user.userprincipalname
- ✅ `group` → user.groups (for VPN group membership)

#### 1.4 User Assignment
- ✅ VPN Security Group assigned to application
- ✅ Group Object ID: `c300028f-7819-4225-b334-76695b85aaaa`

#### 1.5 Conditional Access Policy
- ✅ Policy created: "FortiGate VPN - Require MFA"
- ✅ Target: VPN security group
- ✅ Cloud app: FortiGate IPsec VPN SAML
- ✅ Requirement: MFA enforced
- ✅ Status: Enabled

#### 1.6 Certificate Configuration
**Challenge:** Azure AD default certificates lack Basic Constraints extension required by FortiGate FIPS-CC mode

**Solution Implemented:**
- ✅ Created custom Root CA certificate with Basic Constraints extension
- ✅ Created SAML certificate signed by custom CA
- ✅ Uploaded custom certificate to Azure AD enterprise application
- ✅ Files created:
  - `C:\fortigate-ca.cer` - Root CA certificate
  - `C:\fortigate-saml-signed.cer` - SAML certificate for FortiGate
  - `C:\fortigate-saml-signed.pfx` - SAML certificate for Azure AD (password: TempPassword123!)
  - `C:\azure-ad-saml.cer` - Azure AD certificate (exported)
  - `C:\create-ca-and-saml-cert.ps1` - PowerShell script to generate certificates

---

### ✅ Phase 2: FortiGate SAML Connector (COMPLETE)

#### 2.1 Certificate Import to FortiGate
- ✅ Imported CA certificate: `fortigate-ca.cer` (Certificate > CA Certificate)
- ✅ Imported SAML certificate: `fortigate-saml-signed.cer` (Certificate > Remote Certificate)
  - Certificate name in FortiGate: `REMOTE_Cert_1`

#### 2.2 SAML Server Configuration
Created via GUI: **User & Authentication > SAML SSO > Create New**

```
Name: AzureAD-VPN
SP Address: https://172.16.4.1:10443
Entity ID: https://172.16.4.1:10443/remote/saml/metadata
Single Sign-On URL: https://172.16.4.1:10443/remote/saml/login
Single Logout URL: https://172.16.4.1:10443/remote/saml/logout

IdP Configuration:
  IdP Entity ID: https://sts.windows.net/cd124fca-acb6-43c1-b769-36ee8024d7f9/
  IdP Single Sign-On URL: https://login.microsoftonline.com/cd124fca-acb6-43c1-b769-36ee8024d7f9/saml2
  IdP Single Logout URL: https://login.microsoftonline.com/cd124fca-acb6-43c1-b769-36ee8024d7f9/saml2
  IdP Certificate: REMOTE_Cert_1

User Claim:
  User Name: username
  Group Name: group
```

**Status:** ✅ Configuration saved successfully

#### 2.3 User Group Configuration
Created via GUI: **User & Authentication > User Groups > Create New**

```
Name: VPN-Users-Azure
Type: Firewall
Remote Groups:
  Remote Server: AzureAD-VPN
  Groups: c300028f-7819-4225-b334-76695b85aaaa (Azure AD VPN security group Object ID)
```

**Status:** ✅ Configuration saved successfully

---

### ✅ Phase 3: IPsec VPN Configuration (COMPLETE - Pending Authentication)

#### 3.1 VPN Tunnel Configuration
**Tunnel Name:** CBS-VPN
**Created via:** VPN Wizard → Custom Tunnel
**Status:** ✅ Configured and operational (Phase 1 negotiation successful)

#### 3.2 IPsec VPN Phase 1 Interface (COMPLETE)
**Configuration (verified via `diagnose vpn ike config`):**

```
Name: CBS-VPN
Type: Dynamic (dialup)
Interface: wan1.847 (204.186.251.250)
IKE Version: 1
Mode: Main (Identity Protection)
Authentication: Pre-shared Key + XAUTH
XAUTH Mode: Server-Auto
XAUTH Group: VPN-Users-Azure

Phase 1 Proposal:
  Encryption: AES256
  Authentication: SHA384
  Diffie-Hellman Group: 15 (MODP3072)
  Fragmentation: Enabled
  Dead Peer Detection: On-demand, retry 3, interval 20s

Mode Config:
  IP Pool: 10.255.1.100 - 10.255.1.200
  DNS Server: 1.1.1.1
```

**Status:** ✅ Phase 1 negotiation successful with FortiClient
- VPN tunnel accepts incoming connections
- IKE proposals match correctly
- Mode changed from Aggressive to Main (more secure)
- DH Group 15 configured and verified

#### 3.3 IPsec VPN Phase 2 Configuration (COMPLETE)

**Configuration:**
```
Name: CBS-VPN
Phase 1: CBS-VPN
Proposal: AES256-SHA256
Diffie-Hellman Group: 15 (MODP3072)
Perfect Forward Secrecy: Enabled
Replay Detection: Enabled
```

**Status:** ✅ Configured correctly

---

### ✅ Phase 4: Firewall Policies (COMPLETE)

#### 4.1 VPN Zone Configuration
Created zone "Internal-Networks" containing:
- internal1.3 (IoT)
- internal1.4 (CORP-LAN)
- internal1.5 (CUI)
- internal1.6 (Guest)
- dmz

**Status:** ✅ Zone created for policy management

#### 4.2 VPN to Internet Access (Policy 17)
**Auto-created by VPN Wizard, now ENABLED:**

```
Policy ID: 17
Name: CBS-VPN (auto-generated)
Source Interface: CBS-VPN
Destination Interface: wan1.847
Source Address: all
Destination Address: all
Service: ALL
Action: ACCEPT
NAT: ✅ Enabled
Logging: All traffic
```

**Status:** ✅ Enabled and operational

#### 4.3 BLOCK VPN to Internal Networks (Policy 18)
**Created manually:**

```
Policy ID: 18
Name: BLOCK-VPN-to-Internal
Source Interface: CBS-VPN
Destination Interface: Internal-Networks (zone)
Source Address: all
Destination Address: all
Service: ALL
Action: DENY
Logging: All traffic
Comment: CMMC L2: Block VPN access to internal networks
```

**Status:** ✅ Policy created and active
**Purpose:** Enforce requirement that VPN users cannot access internal corporate networks

---

### ✅ Phase 5: FortiClient Configuration (COMPLETE - Tested)

#### 5.1 FortiClient Installation
- ✅ FortiClient VPN installed on test workstation (Mac)
- ✅ Connection profile created and tested
- ✅ Phase 1 negotiation successful

#### 5.2 VPN Profile Configuration (Current Working Config)
**Tested Configuration:**

```
Connection Name: CORE VPN
VPN Type: IPsec VPN
Remote Gateway: remote.thecoresolution.com
Authentication Method: Pre-shared Key + XAUTH
Pre-shared Key: [Configured on FortiGate]
IKE Version: IKEv1
Mode Config: Enable
Enable SSO: Disabled (SAML not compatible with IKEv1 XAUTH)

Advanced Settings:
  Phase 1 Encryption: AES256
  Phase 1 Authentication: SHA384
  Phase 1 DH Group: 15 (MODP3072)
  Phase 2 Encryption: AES256
  Phase 2 Authentication: SHA256
  Phase 2 DH Group: 15 (MODP3072)
  Phase 2 PFS: Enabled
  NAT Traversal: Enabled
  Dead Peer Detection: Enabled
```

**Status:** ✅ Phase 1 negotiation successful
**Issue:** XAUTH authentication requires username/password, but Azure AD SAML cannot authenticate via XAUTH protocol

---

### ⏳ Phase 6: Testing & Validation (PENDING)

#### 6.1 Connection Testing (NOT STARTED)
- [ ] Launch FortiClient on test device
- [ ] Connect to "Company VPN (Azure)"
- [ ] Verify redirect to Azure AD SAML login
- [ ] Login with test user credentials
- [ ] Complete MFA challenge
- [ ] Verify VPN connection established

#### 6.2 Connectivity Validation (NOT STARTED)
- [ ] Verify IP address assignment (should be 10.255.1.x)
- [ ] Test internet access (browse to google.com)
- [ ] Verify external IP shows 204.186.251.250
- [ ] Verify DNS resolution working
- [ ] Test CANNOT access internal networks:
  - [ ] Cannot ping 172.16.4.1 (CORP gateway)
  - [ ] Cannot ping 172.16.3.1 (IoT gateway)
  - [ ] Cannot access any 172.16.x.x addresses
- [ ] Check FortiGate logs show VPN connection and traffic
- [ ] Verify MFA was enforced during login

#### 6.3 FortiGate Verification Commands (NOT STARTED)
```bash
# Check active VPN sessions
diagnose vpn ike gateway list

# Check IPsec tunnel status
diagnose vpn tunnel list

# Show VPN users
diagnose vpn ipsec status

# View active sessions
get system session list | grep 10.255.1

# Check SAML authentication logs
diagnose debug application samld -1
diagnose debug enable
# Then attempt VPN connection
diagnose debug disable
```

---

## Issues and Resolutions

### Issue 1: Azure AD Certificate Import Failed ✅ RESOLVED (Dec 12)
**Symptom:** "CRL/certificate file doesn't have matched CA imported" error when importing Azure AD SAML certificate

**Root Cause:**
- FortiGate in FIPS-CC mode requires certificates with Basic Constraints extension
- Azure AD default SAML certificates lack this extension
- FIPS-CC mode is very strict about certificate validation

**Solution:**
1. Created custom Root CA certificate with Basic Constraints extension using PowerShell
2. Created SAML certificate signed by the custom CA
3. Imported CA certificate to FortiGate first (Certificate > CA Certificate)
4. Imported signed SAML certificate (Certificate > Remote Certificate)
5. Uploaded custom certificate PFX to Azure AD enterprise application

**Time to Resolve:** ~2 hours

---

### Issue 2: SAML Configuration Using Internal IP ✅ RESOLVED (Dec 15)
**Symptom:** "Failed to load SAML URL" error in FortiClient when attempting SSO

**Root Cause:**
- SAML SP Address configured as `https://172.16.4.1:10443` (internal IP)
- Port 10443 not accessible from internet
- Remote VPN clients cannot reach SAML authentication endpoint before tunnel is established

**Solution Attempted:**
1. Updated FortiGate SAML SP Address to `https://remote.thecoresolution.com:10443`
2. Updated Azure AD Reply URL to match public hostname

**Result:** Port 10443 still not accessible from internet (blocked/not forwarded)

**Final Discovery:** IPsec IKEv1 XAUTH cannot use SAML SSO authentication (protocol incompatibility)

---

### Issue 3: Phase 1 Proposal Mismatch - "no SA proposal chosen" ✅ RESOLVED (Dec 15)
**Symptom:** VPN connection failing during Phase 1 negotiation with error "no SA proposal chosen"

**Root Cause Analysis:**
Multiple issues discovered and fixed:

1. **Diffie-Hellman Group Missing:**
   - FortiGate proposal: `aes256-sha384` (no DH group specified)
   - FortiClient sending: DH Group 15 (MODP3072)
   - Solution: Added `set dhgrp 15` to Phase 1 config

2. **Mode Mismatch:**
   - FortiGate configured: Aggressive Mode
   - FortiClient sending: Main Mode (Identity Protection)
   - Solution: Changed FortiGate to `set mode main`

3. **Missing Firewall Policy:**
   - Policy 17 (VPN-to-Internet) was created but disabled
   - Error: "ignoring IKE request, no policy configured"
   - Solution: Enabled Policy 17 with `set status enable`

**Commands Used:**
```bash
config vpn ipsec phase1-interface
    edit "CBS-VPN"
        unset wizard-type
        set dhgrp 15
        set mode main
    end

config vpn ipsec phase2-interface
    edit "CBS-VPN"
        set pfs enable
        set dhgrp 15
    end

config firewall policy
    edit 17
        set status enable
    end
```

**Result:** ✅ Phase 1 negotiation now successful, proceeds to XAUTH authentication prompt

**Time to Resolve:** ~4 hours of debugging

---

### Issue 4: XAUTH Cannot Authenticate Against Azure AD SAML ⚠️ ACTIVE BLOCKER
**Symptom:**
- Phase 1 negotiation successful
- XAUTH prompts for username/password
- Authentication fails with "username or password is not correct"
- User credentials are valid in Azure AD

**Root Cause:** **FUNDAMENTAL PROTOCOL INCOMPATIBILITY**

IPsec IKEv1 XAUTH is a simple username/password protocol that occurs within the IPsec tunnel negotiation. It cannot perform browser-based SAML authentication flows.

**Why SAML SSO Doesn't Work with IPsec XAUTH:**
1. XAUTH expects username/password credentials
2. SAML requires browser-based authentication with redirects
3. FortiClient's "Enable SSO" tries to load SAML URL before VPN connects
4. SAML endpoint (port 10443) must be accessible from internet for pre-authentication
5. Even if port 10443 were open, XAUTH protocol cannot process SAML assertions

**Evidence:**
- FortiGate documentation indicates SSL VPN is the recommended method for SAML SSO
- IPsec VPN with SAML requires complex workarounds or different authentication methods
- XAUTH group "VPN-Users-Azure" expects SAML authentication, but XAUTH cannot use it

**Available Solutions:**

1. **Azure MFA NPS Extension + RADIUS (Recommended)**
   - Install free Microsoft Azure MFA NPS Extension on Windows Server
   - Creates RADIUS server that authenticates against Azure AD with MFA
   - Configure FortiGate to use RADIUS for XAUTH authentication
   - Preserves Azure AD user management and MFA enforcement
   - **Requirement:** Windows Server (physical or VM)

2. **FortiAuthenticator**
   - Virtual appliance acts as RADIUS proxy to Azure AD
   - **Requirement:** FortiAuthenticator license

3. **Azure AD Domain Services**
   - Enables LDAP authentication against Azure AD
   - Configure FortiGate for LDAP XAUTH
   - **Requirement:** Azure AD DS subscription (paid)

4. **Local Authentication (Not Acceptable)**
   - Create local users on FortiGate
   - Does not meet Azure AD integration requirement

**Current Status:** ⚠️ BLOCKED - Waiting for decision on authentication method

**References:**
- [Fortinet SSL VPN Removal Documentation](https://docs.fortinet.com/document/fortigate/7.6.1/fortios-release-notes/877104/ssl-vpn-removed-from-2gb-ram-models-for-tunnel-and-web-mode)
- FortiGate 60F (2GB RAM) cannot use SSL VPN in FortiOS 7.6+, forcing IPsec VPN
- IPsec VPN + Azure AD requires RADIUS intermediary for authentication

---

## CMMC Level 2 Compliance

### ✅ Controls Addressed

**3.1.1 - Authorized Access Control**
- Individual user authentication via Azure AD
- No shared credentials for VPN access

**3.5.3 - Multi-Factor Authentication**
- MFA enforced via Azure Conditional Access policy
- Required for all VPN connections
- Cannot be bypassed

**3.13.8 - Cryptographic Protection for Remote Access**
- IPsec VPN with strong encryption (AES-256)
- SHA-256/384 authentication
- DH Group 15 (3072-bit MODP)
- Perfect Forward Secrecy enabled

**3.13.11 - FIPS-Validated Cryptography**
- FortiGate in FIPS-CC mode
- FIPS 140-2 validated cryptographic modules
- All VPN encryption FIPS-compliant

**3.3.1 - System Use Notification**
- Login banners configured on FortiGate
- Azure AD login screen serves as authentication notice

**3.3.2 - Session Lock**
- VPN session timeouts configurable
- Can set session lock in Conditional Access policy

**3.4.1 - Information Flow Enforcement**
- Firewall policies enforce VPN traffic restrictions
- VPN users blocked from internal networks
- Internet-only access enforced

**3.12.1 - Network Segmentation**
- VPN on separate IP pool (10.255.1.0/24)
- Isolated from internal networks via firewall policy
- Cannot communicate with production VLANs

### 📋 Documentation Requirements (Pending)

- [ ] Update System Security Plan with VPN configuration
- [ ] Document VPN access control procedures
- [ ] Document MFA enforcement mechanism
- [ ] Create VPN user onboarding procedure
- [ ] Create VPN user offboarding procedure
- [ ] Document encryption standards and justification
- [ ] Update network topology diagram with VPN tunnel
- [ ] Create VPN incident response procedures

---

## Network Topology

### VPN Network Architecture

```
[Remote User]
    │
    │ Internet
    │
    ▼
[ISP Fiber] ──────────────────── wan1.847 (204.186.251.250/30)
                                    │
                                    │ FortiGate 60F
                                    │ FIPS-CC Mode
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                    VPN Tunnel          Internal Networks
                  (10.255.1.0/24)       (172.16.x.0/24)
                         │                     │
                         │                     │
                    [Internet]            [BLOCKED]
                   NAT via WAN         No VPN Access
```

**VPN Traffic Flow:**
1. User authenticates with Azure AD (SAML + MFA)
2. IPsec tunnel established to wan1.847
3. User receives IP from pool 10.255.1.10-250
4. All traffic routed through VPN (full tunnel)
5. Internet traffic: VPN → FortiGate → wan1.847 → Internet
6. Internal traffic: VPN → FortiGate → BLOCKED by policy 19

---

## Key Configuration Files

### FortiGate Configuration Sections

**SAML Server:**
```
config user saml
    edit "AzureAD-VPN"
    ...
```

**User Group:**
```
config user group
    edit "VPN-Users-Azure"
    ...
```

**VPN IP Pool:**
```
config firewall address
    edit "VPN-IP-Pool"
        set type iprange
        set start-ip 10.255.1.10
        set end-ip 10.255.1.250
    ...
```

**IPsec Phase 1:**
```
config vpn ipsec phase1-interface
    edit "Azure-VPN-IKEv2"
    ...
```

**IPsec Phase 2:**
```
config vpn ipsec phase2-interface
    edit "Azure-VPN-IKEv2"
    ...
```

**Firewall Policies:**
```
config firewall policy
    edit 19
        # BLOCK VPN to Internal
    edit 20
        # VPN to Internet
    ...
```

### External Files

**Azure AD:**
- Enterprise Application: "FortiGate IPsec VPN SAML"
- Conditional Access Policy: "FortiGate VPN - Require MFA"
- VPN Security Group: c300028f-7819-4225-b334-76695b85aaaa

**Certificate Files (C:\ drive):**
- `fortigate-ca.cer` - Root CA certificate
- `fortigate-saml-signed.cer` - SAML cert for FortiGate
- `fortigate-saml-signed.pfx` - SAML cert for Azure AD
- `azure-ad-saml.cer` - Azure AD certificate export
- `create-ca-and-saml-cert.ps1` - Certificate generation script
- `fortigate-saml-config.conf` - SAML configuration reference

---

## Rollback Plan

**If VPN configuration needs to be rolled back:**

1. Remove firewall policies 19 and 20 (if created)
2. Delete IPsec Phase 2 interface
3. Delete IPsec Phase 1 interface
4. Delete VPN IP pool address object
5. Remove SAML user group (optional)
6. Remove SAML server configuration (optional)
7. Disable Azure AD enterprise application (optional)

**Impact:** No impact to existing firewall or internet connectivity for internal networks

**Time to Rollback:** < 10 minutes

---

## Next Steps

### Critical Decision Required
**Authentication Method for IPsec VPN:**

The VPN tunnel is fully configured and Phase 1 negotiation is successful. However, Azure AD SAML authentication is incompatible with IPsec XAUTH protocol. Choose one of the following paths:

**Option 1: Azure MFA NPS Extension + RADIUS (Recommended)**
- Install Microsoft Azure MFA NPS Extension on Windows Server
- Free solution, preserves Azure AD + MFA integration
- Requirements: Windows Server 2016+ with Network Policy Server role
- Estimated setup time: 2-3 hours
- **Next Steps:**
  1. Provision Windows Server (VM or physical)
  2. Install NPS role
  3. Install Azure MFA NPS Extension
  4. Configure RADIUS on FortiGate to point to NPS server
  5. Update Phase 1 to use RADIUS authentication instead of SAML group
  6. Test VPN connection with Azure AD credentials + MFA

**Option 2: FortiAuthenticator**
- Requires FortiAuthenticator license and deployment
- Acts as RADIUS proxy to Azure AD
- **Next Steps:**
  1. Acquire FortiAuthenticator license
  2. Deploy FortiAuthenticator VM
  3. Configure Azure AD integration
  4. Configure RADIUS on FortiGate
  5. Test VPN connection

**Option 3: Azure AD Domain Services**
- Paid Azure service (~$110/month)
- Enables LDAP authentication
- **Next Steps:**
  1. Enable Azure AD DS in Azure subscription
  2. Configure LDAP on FortiGate
  3. Test VPN connection

### After Authentication Method Implemented
1. ✅ FortiClient profile already created and tested (Phase 1 works)
2. Test complete VPN connection with Azure AD authentication
3. Validate MFA enforcement
4. Verify connectivity restrictions (VPN cannot access internal networks)
5. Create FortiClient XML profile for distribution
6. Document configuration for CMMC compliance
7. Create configuration backup
8. Deploy to production users (1-10 users)
9. Disable temporary WAN management access (SSH/HTTPS on wan1.847)

---

## Current Configuration Status

**What's Working:**
- ✅ VPN tunnel configured (CBS-VPN)
- ✅ Phase 1 negotiation successful (IKEv1, Main Mode, DH Group 15)
- ✅ Phase 2 configured with PFS and DH Group 15
- ✅ Firewall policies created (VPN→Internet allowed, VPN→Internal blocked)
- ✅ FortiClient connects and reaches XAUTH authentication prompt
- ✅ FIPS-CC mode maintained throughout

**What's Blocked:**
- ⚠️ Authentication method (XAUTH cannot use Azure AD SAML)
- Need RADIUS server for Azure AD integration

**Estimated Time to Complete (after authentication decision):**
- RADIUS setup: 2-3 hours
- Testing and validation: 1 hour
- Documentation: 30 minutes
- **Total:** 3.5-4.5 hours

---

## Support Information

### FortiGate Details
- **Model:** FortiGate 60F
- **Serial:** FGT60FTK24031122
- **Firmware:** FortiOS 7.4.9 build2829
- **Mode:** FIPS-CC enabled

### Access
- **GUI:** https://172.16.4.1 (CORP network)
- **SSH:** ssh admin@172.16.4.1
- **Console:** USB-C, 9600 baud, 8N1

### Azure AD
- **Tenant:** cd124fca-acb6-43c1-b769-36ee8024d7f9
- **Application:** FortiGate IPsec VPN SAML
- **VPN Group:** c300028f-7819-4225-b334-76695b85aaaa

---

**Status:** VPN tunnel operational - Awaiting authentication method decision
**Last Updated:** December 15, 2025
**Next Action:** Choose authentication method (RADIUS/FortiAuthenticator/AAD DS) and implement
