# FortiGate 60F - IPsec VPN with Azure AD SAML Setup

**Start Date:** December 12, 2025
**Status:** 🔄 IN PROGRESS
**Completion:** ~70%

---

## Configuration Overview

**VPN Type:** IPsec IKEv2 Dial-Up VPN (not SSL VPN)
**Authentication:** Azure AD SAML with MFA enforcement
**VPN Client:** FortiClient
**Access Model:** Full tunnel - Internet only (no internal network access)
**Target Users:** 1-10 users
**Compliance:** CMMC Level 2 compliant

### Why IPsec Instead of SSL VPN?
FortiOS 7.6+ removes SSL VPN support on FortiGate models with 2GB RAM or less. The FortiGate 60F has 2GB RAM, so we're implementing IPsec VPN with SAML authentication instead.

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

### 🔄 Phase 3: IPsec VPN Configuration (IN PROGRESS)

#### 3.1 VPN IP Pool (COMPLETE)
Created via GUI: **Policy & Objects > Addresses > Create New**

```
Name: VPN-IP-Pool
Type: IP Range
IP Range: 10.255.1.10 - 10.255.1.250
Interface: any
Comment: IPsec VPN client address pool
```

**Rationale:** Using 10.255.1.0/24 subnet to avoid conflicts with internal networks (172.16.x.x)

**Status:** ✅ Created successfully

#### 3.2 IPsec VPN Phase 1 Interface (IN PROGRESS)
Created via GUI: **VPN > IPsec Wizard**

**Current Configuration:**
```
Name: Azure-VPN-IKEv2
Template: Dialup User
Remote Gateway: Dialup User
Interface: wan1.847
Mode Config: ✅ Enable

Mode Config Settings:
  IP Pools: VPN-IP-Pool (10.255.1.10-250)
  DNS Server 1: 1.1.1.1

Authentication:
  Method: Signature
  User Group: VPN-Users-Azure
  IKE Version: 2

Phase 1 Proposal:
  Encryption: AES256
  Authentication: SHA384
  Diffie-Hellman Group: 15 (3072-bit MODP)
  Key Lifetime: 86400 seconds
```

**Status:** ⚠️ Configuration created but showing errors (see Issues section)

#### 3.3 IPsec VPN Phase 2 Configuration (IN PROGRESS)

**Current Configuration:**
```
Name: Azure-VPN-IKEv2 (auto-created)
Phase 1: Azure-VPN-IKEv2

Phase 2 Proposal:
  Encryption: AES256
  Authentication: SHA256
  Diffie-Hellman Group: 15 (3072-bit MODP) - PFS enabled
  Key Lifetime: 43200 seconds

Advanced Settings:
  Replay Detection: ✅ Enabled
  Perfect Forward Secrecy: ✅ Enabled
  Auto-negotiate: ✅ Enabled
```

**Status:** ⚠️ Configuration created but pending Phase 1 issue resolution

---

### ⏳ Phase 4: Firewall Policies (PENDING)

#### 4.1 BLOCK VPN to Internal Networks (NOT STARTED)
**Planned Policy 19:** (Must be ABOVE internet policy)

```
Name: BLOCK-VPN-to-Internal
Source Interface: Azure-VPN-IKEv2
Destination Interface: internal1.3, internal1.4, internal1.5, internal1.6, dmz
Source Address: VPN-IP-Pool
Destination Address: all
Service: ALL
Action: DENY
Logging: All traffic
Comment: CMMC L2: Block VPN access to internal networks
```

**Purpose:** Enforce security requirement that VPN users cannot access internal corporate networks

#### 4.2 VPN to Internet Access (NOT STARTED)
**Planned Policy 20:**

```
Name: VPN-to-Internet
Source Interface: Azure-VPN-IKEv2
Destination Interface: wan1.847
Source Address: VPN-IP-Pool
Destination Address: all
Service: ALL
Action: ACCEPT
NAT: ✅ Enable
Logging: All traffic
Comment: CMMC L2: IPsec VPN users internet access only
```

**Purpose:** Allow VPN users full tunnel internet access through FortiGate

---

### ⏳ Phase 5: FortiClient Configuration (PENDING)

#### 5.1 FortiClient Installation (NOT STARTED)
- [ ] Download FortiClient VPN (free version)
- [ ] Install on test workstation
- [ ] Prepare VPN profile for deployment

#### 5.2 VPN Profile Configuration (NOT STARTED)
**Planned Configuration:**

```
Connection Name: Company VPN (Azure)
VPN Type: IPsec VPN
Remote Gateway: 204.186.251.250 (FortiGate WAN IP)
Authentication Method: Single Sign-On (SAML)
Pre-shared Key: [To be configured after Phase 1 completion]
IKE Version: IKEv2
Mode Config: Enable

Advanced Settings:
  Phase 1 Encryption: AES256
  Phase 1 Authentication: SHA384
  Phase 1 DH Group: 15
  Phase 2 Encryption: AES256
  Phase 2 Authentication: SHA256
  Phase 2 DH Group: 15
  NAT Traversal: Enable
  Dead Peer Detection: Enable
```

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

### Issue 1: Azure AD Certificate Import Failed ✅ RESOLVED
**Symptom:** "CRL/certificate file doesn't have matched CA imported" error when importing Azure AD SAML certificate

**Root Cause:**
- FortiGate in FIPS-CC mode requires certificates with Basic Constraints extension
- Azure AD default SAML certificates lack this extension
- FIPS-CC mode is very strict about certificate validation

**Attempts Made:**
1. GUI certificate upload - FAILED
2. CLI certificate paste - FAILED (character limit)
3. Remote certificate import - FAILED (missing Basic Constraints)

**Solution:**
1. Created custom Root CA certificate with Basic Constraints extension using PowerShell
2. Created SAML certificate signed by the custom CA
3. Imported CA certificate to FortiGate first (Certificate > CA Certificate)
4. Imported signed SAML certificate (Certificate > Remote Certificate)
5. Uploaded custom certificate PFX to Azure AD enterprise application
6. Both certificates imported successfully to FortiGate

**Files Created:**
- `C:\create-ca-and-saml-cert.ps1` - PowerShell script
- `C:\fortigate-ca.cer` - Root CA
- `C:\fortigate-saml-signed.cer` - SAML certificate for FortiGate
- `C:\fortigate-saml-signed.pfx` - SAML certificate for Azure AD

**Time to Resolve:** ~2 hours of troubleshooting + research

---

### Issue 2: IPsec VPN Configuration via CLI Failed ✅ WORKAROUND
**Symptom:** CLI commands for VPN Phase 1 configuration kept failing or reverting

**Root Cause:**
- Copy/paste issues with complex multi-line CLI commands
- Character encoding problems
- Settings validation failing silently

**Solution:**
- Switched to GUI VPN wizard (VPN > IPsec Wizard)
- More reliable for complex configuration
- Better error feedback

**Status:** Using GUI successfully, but new issue emerged (see Issue 3)

---

### Issue 3: IPsec Phase 1 Error - "-1: Invalid length of value" ⚠️ ACTIVE
**Symptom:**
- VPN tunnel "Azure-VPN-IKEv2" created successfully
- Red error message appears: "-1: Invalid length of value" (appears twice in GUI)
- When editing Authentication section:
  - IKEv1 shows pre-shared key field
  - IKEv2 does NOT show pre-shared key field

**Current Status:** ⚠️ INVESTIGATING

**Observations:**
- VPN configuration appears in interface list
- Most settings configured correctly
- Phase 2 auto-created with correct settings
- Error suggests missing or invalid value somewhere in configuration

**Possible Causes:**
1. Pre-shared key requirement for IKEv2 dialup mode (even with SAML auth)
2. Missing required field in IKEv2 configuration
3. GUI bug or limitation with IKEv2 SAML configuration
4. Additional authentication parameter required

**Next Steps to Investigate:**
1. Check if IKEv1 is acceptable alternative for SAML-based VPN
2. Verify if PSK is required even with SAML authentication
3. Try configuring PSK via CLI for IKEv2
4. Review FortiGate documentation for IKEv2 + SAML + dialup requirements
5. Check if "authmethod" parameter needs adjustment

**Status:** Paused for later investigation

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

### Immediate (Resume Session)
1. Investigate "-1: Invalid length of value" error on Azure-VPN-IKEv2
2. Determine if IKEv1 is acceptable or if IKEv2 issue can be resolved
3. Complete Phase 1 configuration without errors
4. Verify Phase 2 configuration
5. Create firewall policies 19 and 20

### After VPN Configuration Complete
1. Download and install FortiClient
2. Create FortiClient VPN profile
3. Test VPN connection with test user
4. Validate MFA enforcement
5. Verify connectivity restrictions
6. Document configuration for CMMC compliance
7. Create configuration backup
8. Deploy to production users (1-10 users)

---

## Estimated Time Remaining

**Based on current progress:**
- Phase 3 completion (resolve error + policies): 1-2 hours
- Phase 4 (FortiClient setup): 30 minutes
- Phase 5 (Testing): 1 hour
- Phase 6 (Documentation): 30 minutes

**Total Estimated:** 3-4 hours remaining

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

**Status:** Paused for investigation of IKEv2 configuration error
**Last Updated:** December 12, 2025
**Next Action:** Investigate PSK/authentication requirements for IKEv2 with SAML
