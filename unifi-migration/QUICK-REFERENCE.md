# UniFi Migration - Quick Reference

## CloudKey Commands

### Check Network Configuration
```bash
# SSH to CloudKey
ssh root@192.168.168.30  # or current IP

# View current IP and interface
ip addr show eth0

# View routing
ip route

# View DNS
cat /etc/resolv.conf

# View network config file
cat /etc/systemd/network/eth0.network
```

### Change CloudKey IP
```bash
# Backup current config
cp /etc/systemd/network/eth0.network /root/eth0.network.backup

# Option 1: Use sed to change IP
sed -i 's/Address=OLD_IP/Address=NEW_IP/' /etc/systemd/network/eth0.network
sed -i 's/Gateway=OLD_GW/Gateway=NEW_GW/' /etc/systemd/network/eth0.network

# Option 2: Edit with vi
vi /etc/systemd/network/eth0.network
# Press 'i' for insert mode, make changes
# Press Esc, then type ':wq' and Enter to save

# Apply changes
systemctl restart systemd-networkd

# Verify
ip addr show eth0
ip route
ping -c 3 <gateway-ip>
ping -c 3 8.8.8.8
```

### Test Connectivity
```bash
# Test gateway
ping -c 3 172.16.4.1

# Test internet
ping -c 3 8.8.8.8

# Test DNS
ping -c 3 google.com

# Check UniFi service
systemctl status unifi
```

---

## UniFi Device Commands

### SSH to Switch/AP
```bash
# Default credentials (if not changed)
ssh ubnt@<device-ip>
# Password: ubnt

# Or use custom credentials from Device Authentication
ssh <username>@<device-ip>
```

### Force Device to Adopt
```bash
# SSH to device first
ssh ubnt@<device-ip>

# Set controller inform URL
set-inform http://172.16.4.9:8080/inform

# Check device info
info

# Reboot device
reboot
```

---

## FortiGate Commands

### Check Interface Configuration
```bash
# Via CLI
config system interface
    show
end

# Check specific VLAN
config system interface
    edit internal1.4
    show
end
```

### Check DHCP Server
```bash
# View DHCP servers
config system dhcp server
    show
end

# Check leases
diagnose ip dhcp lease list
```

### Check Firewall Policies
```bash
# List all policies
show firewall policy

# Check specific policy by ID
show firewall policy 15
```

### Test Connectivity
```bash
# Ping from FortiGate
execute ping 8.8.8.8

# Traceroute
execute traceroute 8.8.8.8

# Check routing table
get router info routing-table all
```

---

## UniFi Controller Web Interface

### Backup Configuration
1. Settings → System → Backup
2. Click "Download Backup"
3. Save .unf file with date in filename

### Change Port VLAN
1. Devices → Select switch
2. Click on port number
3. Change "Native VLAN / Network"
4. Click Apply

### Check Device Status
1. Devices → UniFi Devices
2. Look for status: Connected, Adopting, Offline
3. Click device to see details (IP, uptime, etc.)

### Reboot Device via Controller
1. Devices → Click device
2. Settings (gear icon) → Manage
3. Click "Reboot"
4. Confirm

### Find Device SSH Credentials
- UniFi OS 4.4.3: Settings → System → Advanced → Device Authentication
- (Location may vary by version)

---

## Network Information

### Current Networks (UniFi)
- Default (1): 192.168.1.0/24
- Management (2): 192.168.168.0/24
- Guest (3): 172.16.3.0/24
- CBS-Corp (4): 172.16.4.0/24 ← **Target**
- Studio VLAN (5): 172.16.5.0/24
- Guest Wi-Fi (6): 172.16.6.0/24

### FortiGate Gateways
- VLAN 2: 192.168.168.168
- VLAN 3: 172.16.3.1
- VLAN 4: 172.16.4.1 ← **Target**
- VLAN 5: 172.16.5.1
- VLAN 6: 172.16.6.1

### Target Configuration
- **CloudKey IP:** 172.16.4.9
- **Gateway:** 172.16.4.1
- **DHCP Range:** 172.16.4.100-200
- **DNS:** 1.1.1.1, 8.8.8.8

---

## Troubleshooting Quick Checks

### CloudKey Won't Come Online
1. Can you ping the gateway?
   ```bash
   ssh root@<cloudkey-ip>
   ping -c 3 172.16.4.1
   ```
2. Check IP configuration: `ip addr show eth0`
3. Check routing: `ip route`
4. Verify port VLAN matches CloudKey IP subnet
5. Check FortiGate has that VLAN configured

### Switches Stay Offline
1. Check if they're getting DHCP: Log into FortiGate → DHCP leases
2. Verify switch uplink port VLAN is correct
3. Power cycle the switch (force DHCP renewal)
4. Check if inter-VLAN routing needed (if on different VLAN than CloudKey)

### Device Gets Wrong IP
1. Check port's Native VLAN assignment
2. Verify VLAN is configured in UniFi Networks
3. Verify FortiGate has that VLAN interface
4. Power cycle device to renew DHCP

### No Internet Access
1. Check FortiGate firewall policy exists for that VLAN → WAN
2. Check NAT is enabled on policy
3. Test from FortiGate: `execute ping 8.8.8.8`
4. Check default route: `get router info routing-table all`

### Can Access Web but Not SSH
1. Check SSH is enabled in CloudKey settings
2. Try from same VLAN as CloudKey (test inter-VLAN routing)
3. Verify SSH password is correct
4. Check firewall rules on FortiGate

---

## Emergency Rollback

### Quick Rollback to SonicWall
```bash
# 1. Reconnect SonicWall physically

# 2. SSH to CloudKey (if accessible)
ssh root@<current-ip>

# 3. Restore old network config
cp /root/eth0.network.backup /etc/systemd/network/eth0.network
systemctl restart systemd-networkd

# Or manually change:
sed -i 's/Address=172.16.4.9/Address=192.168.168.30/' /etc/systemd/network/eth0.network
sed -i 's/Gateway=172.16.4.1/Gateway=192.168.168.168/' /etc/systemd/network/eth0.network
systemctl restart systemd-networkd

# 4. Change port VLANs back via controller
# 5. Power cycle all switches
```

---

## Useful Port Profile Information

### Common UniFi Port Settings

**Access Port (Single VLAN)**
- Native VLAN: Choose network
- Tagged VLAN Management: Usually "Allow All" is fine
- PoE: PoE+ or Off depending on device

**Trunk Port (Multiple VLANs)**
- Native VLAN: Usually management VLAN
- Tagged VLAN Management: Custom, select which VLANs to trunk
- Used for: Switch-to-switch connections, FortiGate uplink

**CloudKey Port Requirements**
- Type: Access port (not trunk)
- Native VLAN: Whatever network CloudKey IP is in
- PoE: PoE+ (CloudKey needs power)

---

## Contact Information

### FortiGate Access
- **URL:** https://172.16.4.1
- **User:** admin
- **Serial:** FGT60FTK24031122

### CloudKey Access
- **URL:** https://192.168.168.30 (current) or https://172.16.4.9 (target)
- **SSH:** root@<cloudkey-ip>
- **Model:** UCK-G2-PLUS
- **Hostname:** CBS-UCKGen2

### Support
- **Fortinet Support:** 1-866-648-4638
- **Ubiquiti Support:** https://help.ui.com

---

**Quick Reference Version:** 1.0
**Last Updated:** January 9, 2026
