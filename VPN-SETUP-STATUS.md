# FortiGate 60F - IPsec VPN with Azure AD (Entra ID) SAML SSO

**Start Date:** December 12, 2025
**Last Updated:** February 13, 2026
**Status:** IMPLEMENTING - IKEv2 + EAP (replaces failed IKEv1 XAUTH approach)

---

## Overview

**VPN Type:** IPsec IKEv2 Dial-Up VPN with EAP
**Authentication:** Azure AD (Entra ID) SAML SSO + MFA via Conditional Access
**VPN Client:** FortiClient 7.2.4+
**Access Model:** Full tunnel - Internet only (no internal network access)
**Target Users:** 1-10 users
**Compliance:** CMMC Level 2 compliant

### Why IPsec (Not SSL VPN)

Fortinet removed SSL VPN from FortiGate models with 2GB RAM starting in FortiOS 7.6.0. The FortiGate 60F has 2GB RAM. IPsec is also hardware-accelerated on the NP6XLite chip.

**Reference:** [Fortinet - SSL VPN Removed from 2GB RAM Models](https://docs.fortinet.com/document/fortigate/7.6.1/fortios-release-notes/877104/ssl-vpn-removed-from-2gb-ram-models-for-tunnel-and-web-mode)

### Why IKEv2 + EAP (Not IKEv1 XAUTH)

The previous attempt used IKEv1 with XAUTH, which failed because XAUTH is a username/password protocol that cannot perform browser-based SAML authentication flows. IKEv2 with EAP natively supports SAML authentication via FortiClient's built-in browser.

| Previous (Failed) | New Approach |
|---|---|
| IKEv1 | IKEv2 |
| XAUTH (username/password only) | EAP (supports SAML browser flow) |
| SAML incompatible with XAUTH | SAML works natively via EAP |
| Needed RADIUS intermediary | Direct Azure AD SAML |

---

## Phase 1: Azure AD (Entra ID) Configuration

### 1.1 Enterprise Application

Create (or reconfigure existing) Enterprise Application in Entra ID:

1. **Entra ID Portal** > Enterprise Applications > New Application
2. Create your own application > "FortiGate IPsec VPN"
3. Set up Single Sign-On > SAML

**Existing application details:**
- **Tenant ID:** `cd124fca-acb6-43c1-b769-36ee8024d7f9`
- **VPN Security Group Object ID:** `c300028f-7819-4225-b334-76695b85aaaa`

### 1.2 SAML Configuration

Configure Basic SAML Configuration in the enterprise app:

| Setting | Value |
|---------|-------|
| Identifier (Entity ID) | `https://remote.thecoresolution.com/remote/saml/metadata` |
| Reply URL (ACS) | `https://remote.thecoresolution.com/remote/saml/login` |
| Sign-on URL | `https://remote.thecoresolution.com/remote/saml/login` |

**Note:** The previous attempt used `https://172.16.4.1:10443` which was unreachable from the internet. The new config uses the public hostname.

### 1.3 SAML Claims

Configure Attributes & Claims:

| Claim Name | Source Attribute |
|------------|------------------|
| `username` | `user.userprincipalname` |
| `group` | `user.groups` |

### 1.4 User Assignment

- Assign VPN security group (`c300028f-7819-4225-b334-76695b85aaaa`) to the application
- Only users in this group can authenticate

### 1.5 Conditional Access Policy

Create (or verify existing) policy:
- **Name:** "FortiGate VPN - Require MFA"
- **Target:** VPN security group
- **Cloud app:** FortiGate IPsec VPN
- **Grant:** Require MFA
- **Status:** Enabled

### 1.6 Download Metadata

Download the **Federation Metadata XML** or **Base64 Certificate** from:
Enterprise App > Single Sign-On > SAML Signing Certificate

**Status:** [ ] Complete

---

## Phase 2: Certificate Handling (FIPS-CC)

FIPS-CC mode requires certificates with the Basic Constraints extension. Azure AD default SAML signing certificates lack this extension, causing import failures on the FortiGate.

### 2.1 Create Custom Root CA Certificate

Run in PowerShell (elevated):

```powershell
# Create Root CA with Basic Constraints
$rootCA = New-SelfSignedCertificate `
    -Subject "CN=FortiGate SAML CA" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyUsageProperty Sign `
    -KeyUsage CertSign, CRLSign `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -NotAfter (Get-Date).AddYears(10) `
    -TextExtension @("2.5.29.19={critical}{text}ca=TRUE")

# Export Root CA certificate (DER format for FortiGate import)
Export-Certificate -Cert $rootCA -FilePath "C:\fortigate-ca.cer" -Type CERT
```

### 2.2 Create SAML Signing Certificate

```powershell
# Create SAML certificate signed by custom CA
$samlCert = New-SelfSignedCertificate `
    -Subject "CN=FortiGate SAML Signing" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -Signer $rootCA `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -NotAfter (Get-Date).AddYears(3) `
    -TextExtension @("2.5.29.19={critical}{text}ca=FALSE")

# Export as PFX for Azure AD upload
$password = ConvertTo-SecureString -String "YourSecurePassword" -Force -AsPlainText
Export-PfxCertificate -Cert $samlCert -FilePath "C:\fortigate-saml-signed.pfx" -Password $password

# Export as CER for FortiGate import
Export-Certificate -Cert $samlCert -FilePath "C:\fortigate-saml-signed.cer" -Type CERT
```

### 2.3 Upload to Azure AD

1. Enterprise App > Single Sign-On > SAML Signing Certificate > Edit
2. Import certificate > Upload the `.pfx` file
3. Set as active signing certificate

### 2.4 Import to FortiGate

1. **CA Certificate:** System > Certificates > CA Certificate > Import
   - Upload `fortigate-ca.cer`
   - Note the assigned name (e.g., `CA_Cert_1`)

2. **Remote Certificate:** System > Certificates > Remote Certificate > Import
   - Upload `fortigate-saml-signed.cer`
   - Note the assigned name (e.g., `REMOTE_Cert_1`)

**Previous certificate files (from earlier attempt, may be reusable):**
- `C:\fortigate-ca.cer` - Root CA certificate
- `C:\fortigate-saml-signed.cer` - SAML certificate for FortiGate
- `C:\fortigate-saml-signed.pfx` - SAML certificate for Azure AD
- `C:\create-ca-and-saml-cert.ps1` - Certificate generation script

**Status:** [ ] Complete (certificates from previous attempt may still be valid)

---

## Phase 3: FortiGate SAML Configuration

### 3.1 SAML Server

**Important:** Delete the old `AzureAD-VPN` SAML config first if it exists with the old URLs.

```
config user saml
    edit "AzureAD-VPN"
        set entity-id "https://remote.thecoresolution.com/remote/saml/metadata"
        set single-sign-on-url "https://remote.thecoresolution.com/remote/saml/login"
        set single-logout-url "https://remote.thecoresolution.com/remote/saml/logout"
        set idp-entity-id "https://sts.windows.net/cd124fca-acb6-43c1-b769-36ee8024d7f9/"
        set idp-single-sign-on-url "https://login.microsoftonline.com/cd124fca-acb6-43c1-b769-36ee8024d7f9/saml2"
        set idp-single-logout-url "https://login.microsoftonline.com/cd124fca-acb6-43c1-b769-36ee8024d7f9/saml2"
        set idp-cert "REMOTE_Cert_1"
        set user-name "username"
        set group-name "group"
    next
end
```

### 3.2 User Group

```
config user group
    edit "VPN-Users-Azure"
        set member "AzureAD-VPN"
    next
end
```

### 3.3 IKE SAML Port and Interface Binding

```
config system global
    set auth-ike-saml-port 10443
end

config system interface
    edit "wan1.847"
        set ike-saml-server "AzureAD-VPN"
    next
end
```

**Note:** Port 10443 on the WAN IP (204.186.251.250) must be reachable from VPN clients for the SAML browser flow to work.

### 3.4 Authentication Certificate

```
config user setting
    set auth-cert "VPN_Certificate"
end
```

**Note:** `VPN_Certificate` should be a server certificate on the FortiGate used for the SAML/HTTPS endpoint. If using the factory cert, use `Fortinet_Factory`.

**Status:** [ ] Complete

---

## Phase 4: IPsec VPN Tunnel (IKEv2 + EAP)

### 4.1 Delete Old CBS-VPN Tunnel (if exists)

If the old IKEv1 tunnel still exists, remove it first:

```
config firewall policy
    delete 17
    delete 18
end

config vpn ipsec phase2-interface
    delete "CBS-VPN"
end

config vpn ipsec phase1-interface
    delete "CBS-VPN"
end
```

**Note:** Adjust policy IDs as needed. Delete policies referencing the tunnel before deleting the tunnel itself.

### 4.2 Phase 1 (IKEv2 with EAP for SAML)

```
config vpn ipsec phase1-interface
    edit "CBS-VPN"
        set type dynamic
        set interface "wan1.847"
        set ike-version 2
        set authmethod signature
        set mode-cfg enable
        set proposal aes256-sha256
        set dhgrp 15
        set eap enable
        set eap-identity send-request
        set authusrgrp "VPN-Users-Azure"
        set ipv4-start-ip 10.255.1.100
        set ipv4-end-ip 10.255.1.200
        set ipv4-netmask 255.255.255.0
        set dns-mode auto
        set dpd on-idle
        set dpd-retrycount 3
        set dpd-retryinterval 20
    next
end
```

**Key settings explained:**
- `ike-version 2` — Required for EAP/SAML support
- `authmethod signature` — Certificate-based auth (not PSK)
- `eap enable` — Enables EAP authentication, which triggers SAML flow
- `eap-identity send-request` — FortiGate requests identity from client
- `dhgrp 15` — DH Group 15 (3072-bit MODP), FIPS-compliant
- `proposal aes256-sha256` — FIPS-compliant encryption

### 4.3 Phase 2

```
config vpn ipsec phase2-interface
    edit "CBS-VPN"
        set phase1name "CBS-VPN"
        set proposal aes256-sha256
        set dhgrp 15
        set pfs enable
        set replay enable
    next
end
```

**Status:** [ ] Complete

---

## Phase 5: Firewall Policies

### 5.1 VPN to Internet (ALLOW)

```
config firewall policy
    edit 0
        set name "VPN-to-Internet"
        set srcintf "CBS-VPN"
        set dstintf "wan1.847"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set nat enable
        set logtraffic all
        set status enable
    next
end
```

### 5.2 Block VPN to Internal Networks (DENY)

```
config firewall policy
    edit 0
        set name "BLOCK-VPN-to-Internal"
        set srcintf "CBS-VPN"
        set dstintf "internal" "internal.3" "internal.4" "internal.5" "internal.6"
        set srcaddr "all"
        set dstaddr "all"
        set action deny
        set schedule "always"
        set service "ALL"
        set logtraffic all
        set comments "CMMC L2: Block VPN access to internal networks"
        set status enable
    next
end
```

**IMPORTANT: Policy Order**
The ALLOW policy (VPN-to-Internet) must be **above** the DENY policy (BLOCK-VPN-to-Internal) in the policy list. FortiGate evaluates policies top-to-bottom and uses the first match.

To verify/adjust order:
```
show firewall policy
```

To move policies:
```
config firewall policy
    move <deny-policy-id> after <allow-policy-id>
end
```

**Status:** [ ] Complete

---

## Phase 6: FortiClient Configuration

### 6.1 Requirements

- **FortiClient version:** 7.2.4 or later (required for IPsec SAML support)
- **Platform:** Windows, macOS, or Linux

### 6.2 VPN Profile

Create IPsec VPN connection in FortiClient:

| Setting | Value |
|---------|-------|
| Connection Name | CORE VPN |
| VPN Type | IPsec VPN |
| Remote Gateway | `remote.thecoresolution.com` |
| IKE Version | 2 |
| Authentication | EAP |

**Connection flow:**
1. User clicks "Connect" in FortiClient
2. FortiClient initiates IKEv2 to `remote.thecoresolution.com`
3. FortiGate responds with EAP challenge
4. FortiClient opens embedded browser for Azure AD login
5. User authenticates with Azure AD credentials
6. User completes MFA challenge (Conditional Access)
7. Azure AD returns SAML assertion to FortiGate
8. FortiGate validates assertion and establishes tunnel
9. User receives IP from 10.255.1.100-200 pool
10. All traffic routes through VPN tunnel

### 6.3 Testing Checklist

- [ ] FortiClient 7.2.4+ installed
- [ ] VPN profile created with IKEv2 + EAP settings
- [ ] Connection initiates and opens Azure AD login
- [ ] Azure AD authentication succeeds
- [ ] MFA challenge completes
- [ ] VPN tunnel establishes
- [ ] IP assigned from 10.255.1.x pool
- [ ] Internet access works (browse to google.com)
- [ ] External IP shows as 204.186.251.250
- [ ] DNS resolution works
- [ ] Cannot ping 172.16.4.1 (CORP gateway)
- [ ] Cannot ping 172.16.3.1 (IoT gateway)
- [ ] Cannot access any 172.16.x.x addresses
- [ ] FortiGate logs show VPN session and traffic

**Status:** [ ] Complete

---

## Phase 7: Verification

### Diagnostic Commands

```bash
# Check IKE sessions
diagnose vpn ike gateway list

# Check IPsec tunnels
diagnose vpn tunnel list

# Check VPN status
diagnose vpn ipsec status

# Debug SAML authentication (run before connecting)
diagnose debug application samld -1
diagnose debug enable
# ... attempt VPN connection ...
diagnose debug disable

# Check active sessions from VPN pool
get system session list | grep 10.255.1

# Check firewall policy hit counts
diagnose firewall policy list
```

### Expected Results

| Check | Expected |
|-------|----------|
| IKE gateway | Active session with client IP |
| Tunnel status | UP with traffic counters |
| Client IP | 10.255.1.100-200 range |
| Internet access | Working via NAT through wan1.847 |
| Internal access | Blocked by deny policy |
| SAML auth | Successful assertion in samld debug |

**Status:** [ ] Complete

---

## Known Gotchas

1. **FIPS-CC certificates** — Azure AD default certs lack Basic Constraints extension. Must use custom CA workaround (Phase 2).

2. **auth-ike-saml-port (10443)** — Must be set in system global, and port 10443 must be reachable on the WAN IP from VPN clients for the SAML browser redirect.

3. **ike-saml-server** — Must be bound to the WAN interface (`wan1.847`) so the FortiGate serves the SAML endpoint on the correct IP.

4. **FortiClient version** — Must be 7.2.4+ for IPsec SAML/EAP support. Older versions don't support EAP with SAML.

5. **Policy order** — VPN-to-Internet ALLOW must be evaluated before VPN-to-Internal DENY.

6. **DNS for VPN clients** — `dns-mode auto` in Phase 1 uses the FortiGate's DNS settings. Clients will use 8.8.8.8/8.8.4.4.

7. **Certificate for auth-cert** — The `auth-cert` under `user setting` must be a valid server certificate. Use `Fortinet_Factory` if no custom server cert is configured.

---

## CMMC Level 2 Compliance

### Controls Addressed

| Control | Description | How Addressed |
|---------|-------------|---------------|
| 3.1.1 | Authorized Access Control | Individual user auth via Azure AD |
| 3.5.3 | Multi-Factor Authentication | MFA via Azure Conditional Access |
| 3.13.8 | Cryptographic Protection (Remote Access) | AES-256, SHA-256, DH Group 15, PFS |
| 3.13.11 | FIPS-Validated Cryptography | FIPS-CC mode, FIPS 140-2 modules |
| 3.3.1 | System Use Notification | Login banners + Azure AD login screen |
| 3.4.1 | Information Flow Enforcement | Deny policy blocks VPN-to-internal |
| 3.12.1 | Network Segmentation | VPN on 10.255.1.0/24, isolated from production |

---

## Network Architecture

```
[Remote User]
    |
    | Internet
    |
    v
[FortiClient 7.2.4+]
    |
    | IKEv2 + EAP (SAML SSO)
    |
    v
[ISP Fiber] ---- wan1.847 (204.186.251.250/30)
                    |
                    | FortiGate 60F (FIPS-CC)
                    | SAML endpoint: :10443
                    |
              +-----+------+
              |            |
         VPN Tunnel    Internal Networks
       (10.255.1.0/24) (172.16.x.0/24)
              |            |
              |            |
         [Internet]   [BLOCKED]
        NAT via WAN   No VPN Access

Authentication Flow:
1. FortiClient -> IKEv2 -> FortiGate
2. FortiGate -> EAP Challenge -> FortiClient
3. FortiClient -> Opens browser -> Azure AD login
4. User authenticates + MFA
5. Azure AD -> SAML assertion -> FortiGate (port 10443)
6. FortiGate validates -> Tunnel established
```

---

## Previous Attempt Summary (December 2025)

The first attempt used IKEv1 with XAUTH + SAML, which is a fundamental protocol incompatibility:
- Phase 1 IKEv1 negotiation worked (Main Mode, DH Group 15)
- XAUTH prompted for username/password but could not perform SAML browser flow
- SAML endpoint on internal IP (172.16.4.1:10443) was unreachable from internet
- **Conclusion:** XAUTH is username/password only; SAML requires browser-based flow; IKEv2 EAP is the correct approach

Issues resolved during previous attempt that carry forward:
- FIPS-CC certificate workaround (custom CA with Basic Constraints)
- Azure AD enterprise app, claims, Conditional Access policy (reusable)
- Firewall policy design (VPN-to-Internet allow, VPN-to-Internal deny)

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
- **Application:** FortiGate IPsec VPN (SAML)
- **VPN Group:** c300028f-7819-4225-b334-76695b85aaaa

### Certificate Files (C:\ drive)
- `fortigate-ca.cer` - Root CA certificate
- `fortigate-saml-signed.cer` - SAML cert for FortiGate
- `fortigate-saml-signed.pfx` - SAML cert for Azure AD
- `create-ca-and-saml-cert.ps1` - Certificate generation script

---

**Next Action:** Start at Phase 1 — reconfigure Azure AD enterprise app SAML URLs, then proceed through each phase sequentially.
