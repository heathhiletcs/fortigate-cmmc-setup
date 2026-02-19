# FortiGate 60F - IPsec VPN with Azure AD (Entra ID) SAML SSO

**Start Date:** December 12, 2025
**Last Updated:** February 18, 2026
**Status:** BLOCKED - "gw validation failed" during IKE_AUTH (see Troubleshooting section)

---

## Overview

**VPN Type:** IPsec IKEv2 Dial-Up VPN with EAP
**Authentication:** Azure AD (Entra ID) SAML SSO + MFA via Conditional Access
**VPN Client:** FortiClient 7.4.3.1790 (standalone, no EMS)
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

**CRITICAL: FIPS-CC also requires SHA-256+ signatures. SHA-1 is silently rejected.**

### 2.1 SAML Certificates (for Azure AD assertion validation)

These were created in the first attempt and are still active:

- **CA_Cert_1** on FortiGate = CN=FortiGate SAML CA (custom root CA with Basic Constraints)
- **REMOTE_Cert_1** on FortiGate = CN=FortiGate SAML Signing (for Azure AD SAML assertion validation)
- Azure AD enterprise app uses the matching PFX to sign SAML assertions

**Status:** [x] Complete - SAML auth works (Azure AD login + MFA succeeds)

### 2.2 VPN Client Certificates (for IKE_AUTH in FIPS-CC mode)

FIPS-CC mode requires `authmethod signature` on phase1-interface, which requires a `peer` with `ca` and a `certificate`. This means the VPN client must present a certificate during IKE_AUTH, and the FortiGate must present its own server certificate.

**Current VPN certificate script:** `~/Downloads/Generate-VPN-Certs-SHA256.ps1`

```powershell
# Generate VPN CA and Client Certificate with SHA-256
# Run as Administrator
# FIPS-CC mode requires SHA-256 (SHA-1 is rejected)

# Remove old FortiGate VPN certs
Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*FortiGate VPN*" } | Remove-Item -Force

# Generate new CA with SHA256
$newCA = New-SelfSignedCertificate -Subject "CN=FortiGate VPN CA" -HashAlgorithm SHA256 `
    -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 `
    -KeyUsageProperty Sign -KeyUsage CertSign, CRLSign `
    -CertStoreLocation "Cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(10) `
    -TextExtension @("2.5.29.19={critical}{text}ca=TRUE")
Export-Certificate -Cert $newCA -FilePath "C:\temp\fortigate-vpn-ca-sha256.cer" -Type CERT

# Generate client cert with SHA256
$clientCert = New-SelfSignedCertificate -Subject "CN=FortiGate VPN Client" -HashAlgorithm SHA256 `
    -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 `
    -Signer $newCA -CertStoreLocation "Cert:\LocalMachine\My" `
    -NotAfter (Get-Date).AddYears(3) `
    -TextExtension @("2.5.29.19={critical}{text}ca=FALSE") -KeyUsage DigitalSignature
$password = ConvertTo-SecureString -String "FortiVPN2026!" -Force -AsPlainText
Export-PfxCertificate -Cert $clientCert -FilePath "C:\temp\fortigate-vpn-client-sha256.pfx" -Password $password
```

**Current Windows certificates:**
- CN=FortiGate VPN CA (Thumbprint: F35C1B64..., SHA-256, in LocalMachine\My)
- CN=FortiGate VPN Client (Thumbprint: 56DA5666..., SHA-256, in LocalMachine\My)

**FortiGate CA certificates:**
- CA_Cert_1 = CN=FortiGate SAML CA (for SAML assertion validation)
- CA_Cert_2 = CN=FortiGate VPN CA (old SHA-1 version — DO NOT USE)
- CA_Cert_3 = CN=FortiGate VPN CA (SHA-256 version — ACTIVE for VPN peer validation)

**Status:** [x] Complete - Certs generated and imported, but see Troubleshooting section

### 2.3 Lessons Learned — Certificates

1. **SHA-256 is mandatory:** PowerShell `New-SelfSignedCertificate` defaults to SHA-1 when using `-Signer`. Must add `-HashAlgorithm SHA256` explicitly.
2. **Basic Constraints required:** FIPS-CC rejects certs without `ca=TRUE` (for CA certs) or `ca=FALSE` (for end-entity certs).
3. **Select correct cert in FortiClient:** FortiClient dropdown shows both CA and client certs. Must select the client cert (CN=FortiGate VPN Client), not the CA.
4. **MS-Organization-Access CA is inaccessible:** Azure AD device certs are signed by a tenant-specific CA that is NOT available via any public API. Cannot use Azure device certs for VPN auth.

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

**CURRENT LIVE CONFIG (as of Feb 18, 2026):**

```
config vpn ipsec phase1-interface
    edit "CBS-VPN"
        set type dynamic
        set interface "wan1.847"
        set ike-version 2
        set authmethod signature
        set net-device enable
        set mode-cfg enable
        set proposal aes256-sha256
        set dpd on-idle
        set eap enable
        set eap-identity send-request
        set certificate "Fortinet_Factory"
        set peer "AzureAD-VPN-Peer"
        set ipv4-start-ip 10.255.1.100
        set ipv4-end-ip 10.255.1.200
        set ipv4-netmask 255.255.255.0
        set dns-mode auto
    next
end
```

**Peer config:**
```
config user peer
    edit "AzureAD-VPN-Peer"
        set ca "CA_Cert_3"
    next
end
```

**Key settings explained:**
- `ike-version 2` — Required for EAP/SAML support
- `authmethod signature` — Certificate-based auth (FIPS-CC requires this)
- `eap enable` — Enables EAP authentication, which triggers SAML flow
- `eap-identity send-request` — FortiGate requests identity from client
- `certificate "Fortinet_Factory"` — FortiGate's own cert presented to client during IKE_AUTH
- `peer "AzureAD-VPN-Peer"` — Validates client cert against CA_Cert_3
- `proposal aes256-sha256` — FIPS-compliant encryption

**MISSING (removed during debugging, needs to be re-added):**
- `set authusrgrp "VPN-Users-Azure"` — Required for SAML user group matching
- `set dhgrp 15` — DH Group 15 was in original config, may have been lost

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

- **FortiClient version:** 7.4.3.1790 (standalone, no EMS)
- **Platform:** Windows 11
- **Note:** Standalone FortiClient only has two auth methods: "X.509 Certificate" and "Pre-shared Key" (no explicit EAP option — EAP is implied when SSO is enabled)

### 6.2 Current VPN Profile

| Setting | Value |
|---------|-------|
| Connection Name | Work |
| VPN Type | IPsec VPN |
| Remote Gateway | `remote.thecoresolution.com` |
| IKE Version | 2 |
| Mode Config | Enabled |
| Authentication Method | X.509 Certificate |
| Client Certificate | FortiGate VPN Client / FortiGate VPN CA |
| SSO Enabled | Yes |
| SSO Port | 10443 |
| IKE UDP Port | 500 |

**SAML flow works:** Azure AD login page appears, user authenticates + MFA succeeds.
**Tunnel does NOT establish:** "gw validation failed" during IKE_AUTH (see Troubleshooting).

### 6.3 Expected Connection Flow

1. User clicks "Connect" in FortiClient
2. FortiClient initiates IKEv2 to `remote.thecoresolution.com`
3. IKE_SA_INIT completes (DH exchange)
4. IKE_AUTH: FortiClient presents client cert, FortiGate validates against peer CA
5. FortiGate responds with EAP challenge (because `eap enable`)
6. FortiClient opens embedded browser for Azure AD login (SSO port 10443)
7. User authenticates with Azure AD credentials + MFA
8. Azure AD returns SAML assertion to FortiGate
9. FortiGate validates assertion against SAML server config
10. FortiGate sends EAP-Success, tunnel established
11. User receives IP from 10.255.1.100-200 pool

**Current failure point:** Step 4 — "gw validation failed" before EAP/SAML starts.

### 6.3 Testing Checklist

- [x] FortiClient 7.4.3 installed
- [x] VPN profile created with IKEv2 settings
- [x] SSO enabled with port 10443
- [x] Connection initiates and opens Azure AD login
- [x] Azure AD authentication succeeds
- [x] MFA challenge completes
- [ ] **BLOCKED:** VPN tunnel establishes (gw validation failed)
- [ ] IP assigned from 10.255.1.x pool
- [ ] Internet access works (browse to google.com)
- [ ] External IP shows as 204.186.251.250
- [ ] DNS resolution works
- [ ] Cannot ping 172.16.4.1 (CORP gateway)
- [ ] Cannot access any 172.16.x.x addresses
- [ ] FortiGate logs show VPN session and traffic

**Status:** BLOCKED — see Troubleshooting section

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

## Troubleshooting — "gw validation failed" (CURRENT BLOCKER)

### Problem

IKE_AUTH completes the certificate exchange but fails with "gw validation failed" before EAP/SAML can start. The tunnel never establishes and no IP is assigned.

Debug output pattern:
```
ike 0:CBS-VPN: received cert
ike 0:CBS-VPN: received peer identifier DER_ASN1_DN 'CN = FortiGate VPN Client'
ike 0:CBS-VPN: gw validation failed
```

### What Works

- IKE_SA_INIT succeeds (DH exchange, proposals match)
- FortiClient SSO triggers Azure AD login page on port 10443
- Azure AD SAML authentication + MFA succeeds
- Client cert is SHA-256 signed by CA_Cert_3 (FIPS-CC compatible)
- FortiGate peer trusts CA_Cert_3

### What We've Tried (All Failed)

| Attempt | Result |
|---------|--------|
| `mandatory-ca-verify disable` | Blocked by FIPS-CC (command parse error, -61) |
| SHA-256 certs (replaced SHA-1) | Still gw validation failed |
| Removed CN filter from peer | Still gw validation failed |
| Removed `authusrgrp` from phase1 | Still gw validation failed |
| Different client certs | Same error regardless of cert |

### Research Findings (Feb 18, 2026)

Based on Fortinet docs, KB articles, and community posts:

**Root Cause Theory 1 — FortiGate server certificate CN mismatch (MOST LIKELY):**
- FortiGate presents `Fortinet_Factory` cert during IKE_AUTH
- `Fortinet_Factory` CN is the device serial number (FGT60FTK24031122), NOT `remote.thecoresolution.com`
- Fortinet docs state: "the certificate's CN should match the IPsec VPN remote gateway's FQDN"
- FortiClient validates the gateway cert and rejects it due to CN mismatch
- The FortiGate logs this client rejection as "gw validation failed"
- **Fix:** Generate a server cert with CN=remote.thecoresolution.com signed by our VPN CA, import to FortiGate, set as `certificate` in phase1

**Root Cause Theory 2 — VPN CA not in Windows Trusted Root store:**
- Our VPN CA cert is in `Cert:\LocalMachine\My` (Personal store)
- FortiClient validates the FortiGate's server cert chain
- If the CA that signed the server cert isn't in the Trusted Root CA store, validation fails
- **Fix:** Copy VPN CA cert to `Cert:\LocalMachine\Root` (Trusted Root CA store)

**Root Cause Theory 3 — Missing Enhanced Key Usage (EKU) on client cert:**
- Our client cert only has Key Usage: DigitalSignature
- IKEv2 client certs may need EKU: `clientAuth` (1.3.6.1.5.5.7.3.2) or `ipsecIKE` (1.3.6.1.5.5.8.2.2)
- **Fix:** Regenerate client cert with proper EKU extensions

**Root Cause Theory 4 — Missing authusrgrp:**
- We removed `authusrgrp "VPN-Users-Azure"` during debugging
- Fortinet docs show `authusrgrp` is required for SAML user matching
- Without it, EAP/SAML flow cannot complete
- **Fix:** Re-add `set authusrgrp "VPN-Users-Azure"` to phase1

**Root Cause Theory 5 — EAP requires EMS:**
- Fortinet troubleshooting docs reference EMS for enabling EAP on FortiClient
- "When EAP is disabled in EMS or the FortiGate, gw validation failed error"
- Standalone FortiClient may not negotiate EAP properly without EMS
- FortiClient only shows PSK and X.509 Certificate auth methods (no explicit EAP toggle)
- **Mitigation:** SSO checkbox may handle this; if not, EMS may be required

### Recommended Fix Order

1. **Generate FortiGate server cert with correct CN** — Create cert with CN=remote.thecoresolution.com signed by VPN CA, import to FortiGate as server cert, set in phase1
2. **Import VPN CA to Windows Trusted Root store** — Ensure FortiClient trusts our CA chain
3. **Re-add authusrgrp** — `set authusrgrp "VPN-Users-Azure"`
4. **Regenerate client cert with EKU** — Add clientAuth and ipsecIKE EKU extensions
5. **Try `eap-cert-auth enable`** — Enables dual cert + EAP authentication mode
6. **If all fail: evaluate FortiClient EMS** — May be required for proper EAP negotiation

### Reference Links

- [Fortinet KB: How to fix 'gw validation failed' error, IPsec Dial-up using IKEv2](https://community.fortinet.com/t5/FortiGate/Technical-Tip-How-to-fix-gw-validation-failed-error-IPsec-Dial/ta-p/339644)
- [Fortinet KB: Microsoft Entra ID SAML authentication for Dial-up IPsec VPN](https://community.fortinet.com/t5/FortiGate/Technical-Tip-How-to-configure-Microsoft-Entra-ID-SAML/ta-p/307457)
- [Fortinet Docs: IPsec IKEv2 VPN 2FA with EAP and certificate authentication](https://docs.fortinet.com/document/fortigate/7.4.8/administration-guide/298520/ipsec-ikev2-vpn-2fa-with-eap-and-certificate-authentication)
- [Fortinet Docs: Troubleshooting IPsec VPN IKEv2 with SAML authentication](https://docs.fortinet.com/document/forticlient/7.4.3/ems-administration-guide/521963/troubleshooting-ipsec-vpn-ikev2-with-saml-authentication)
- [Fortinet Docs: SAML-based authentication for FortiClient IPsec VPN](https://docs.fortinet.com/document/fortigate/7.2.0/new-features/951346/saml-based-authentication-for-forticlient-remote-access-dialup-ipsec-vpn-clients)
- [FortiGate IPsec VPN with SAML (Andrew Travis blog)](https://www.andrewtravis.com/blog/ipsec-vpn-with-saml)
- [Fortinet KB: Certificate Authentication for FortiClient IPsec with SAML](https://community.fortinet.com/t5/FortiGate/Technical-Tip-Certificate-Authentication-for-FortiClient-remote/ta-p/411481)

---

## Known Gotchas

1. **FIPS-CC certificates** — Azure AD default certs lack Basic Constraints extension. Must use custom CA workaround (Phase 2).

2. **FIPS-CC SHA-256 requirement** — SHA-1 signed certificates are silently rejected. PowerShell defaults to SHA-1 with `-Signer` parameter. Always use `-HashAlgorithm SHA256`.

3. **FIPS-CC blocks many commands** — `mandatory-ca-verify disable`, `split-tunnel disable`, and others return "command parse error" (-61). Cannot relax security settings.

4. **FIPS-CC requires authmethod signature** — Cannot use PSK-only auth. Must have `peer` with `ca` and `certificate` on phase1. This adds certificate validation complexity.

5. **auth-ike-saml-port (10443)** — Must be set in system global, and port 10443 must be reachable on the WAN IP from VPN clients for the SAML browser redirect.

6. **ike-saml-server** — Must be bound to the WAN interface (`wan1.847`) so the FortiGate serves the SAML endpoint on the correct IP.

7. **FortiClient version** — Must be 7.2.4+ for IPsec SAML/EAP support. We're using 7.4.3.1790 standalone.

8. **FortiClient cert selection** — Dropdown shows both CA and client certs from the same store. Must carefully select the client cert, not the CA cert.

9. **FortiClient hangs on disconnect** — Full tunnel settings or config changes can cause FortiClient to hang during disconnect. Fix: `taskkill /F /IM FortiClient.exe` + `taskkill /F /IM FortiTray.exe`.

10. **Policy order** — VPN-to-Internet ALLOW must be evaluated before VPN-to-Internal DENY.

11. **DNS for VPN clients** — `dns-mode auto` in Phase 1 uses the FortiGate's DNS settings. Clients will use 8.8.8.8/8.8.4.4.

12. **Certificate for auth-cert** — The `auth-cert` under `user setting` must be a valid server certificate. Use `Fortinet_Factory` if no custom server cert is configured.

13. **Server cert CN must match gateway FQDN** — Fortinet docs say the FortiGate's certificate CN should match the IPsec VPN gateway FQDN (remote.thecoresolution.com). Fortinet_Factory CN is the serial number.

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
- **Firmware:** FortiOS 7.4.11 build2878 (Mature)
- **Mode:** FIPS-CC enabled

### Access
- **GUI:** https://172.16.4.1 (CORP network)
- **SSH:** ssh admin@172.16.4.1
- **Console:** USB-C, 9600 baud, 8N1

### Azure AD
- **Tenant:** cd124fca-acb6-43c1-b769-36ee8024d7f9
- **Application:** FortiGate IPsec VPN (SAML)
- **VPN Group:** c300028f-7819-4225-b334-76695b85aaaa

### Certificate Files
**SAML certs (C:\ drive, from first attempt):**
- `fortigate-ca.cer` - SAML Root CA certificate
- `fortigate-saml-signed.cer` - SAML cert for FortiGate
- `fortigate-saml-signed.pfx` - SAML cert for Azure AD

**VPN certs (C:\temp, current SHA-256):**
- `fortigate-vpn-ca-sha256.cer` - VPN CA certificate (imported as CA_Cert_3)
- `fortigate-vpn-client-sha256.pfx` - VPN client cert (password: FortiVPN2026!)

**Scripts:**
- `~/Downloads/Generate-VPN-Certs-SHA256.ps1` - Current VPN cert generation script

---

**Next Action:** Fix "gw validation failed" — follow the Recommended Fix Order in the Troubleshooting section. Start with generating a FortiGate server cert with CN=remote.thecoresolution.com.
