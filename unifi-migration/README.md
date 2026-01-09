# UniFi CloudKey Migration Documentation

## Overview

This folder contains complete documentation for migrating UniFi CloudKey Plus (Gen2) and all managed UniFi devices from a SonicWall network to the FortiGate 60F firewall.

**Migration Status:** Paused - January 9, 2026
**Current State:** Reverted to SonicWall, all devices operational

---

## Documentation Files

### 📋 [MIGRATION-PLAN.md](MIGRATION-PLAN.md) - **START HERE**
Complete migration plan with:
- Current network configuration
- CloudKey details and access information
- What was tried and what didn't work
- Recommended approach for next attempt
- Step-by-step migration procedures
- Rollback plan
- Questions to answer before next attempt

**Read this first** to understand the full situation.

### ⚡ [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
Quick reference guide with:
- Common commands for CloudKey, FortiGate, UniFi devices
- Network information and IP addresses
- Port configuration examples
- Emergency rollback procedures
- Support contact information

**Use this during migration** for quick command lookup.

### 🔧 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
Detailed troubleshooting guide with:
- Issues encountered during January 9 attempt
- Root causes and solutions
- Diagnostic commands
- Common error messages
- When to consider starting over

**Reference this when problems occur** during migration.

---

## Quick Summary

### Goal
Move UniFi CloudKey and all managed devices from SonicWall (192.168.168.0/24) to FortiGate CBS-Corp VLAN (172.16.4.0/24).

### Current State
- **CloudKey:** 192.168.168.30 on SonicWall
- **All Devices:** Online and operational on SonicWall
- **FortiGate:** Configured and ready (internal1.4 = 172.16.4.1/24)

### Target State
- **CloudKey:** 172.16.4.9 on FortiGate VLAN 4
- **All Devices:** DHCP IPs in 172.16.4.100-200 range
- **Gateway:** FortiGate at 172.16.4.1

### Key Challenge
Switches have DHCP IPs from old network and can't automatically reconnect when CloudKey moves to new network. Solution requires power cycling switches after CloudKey migration.

---

## Before Next Attempt

Review the **Next Session Checklist** in [MIGRATION-PLAN.md](MIGRATION-PLAN.md#next-session-checklist):

- [ ] Read all documentation
- [ ] Verify current operational state
- [ ] Create fresh backups
- [ ] Document current port configurations
- [ ] Test FortiGate VLAN 4 with laptop
- [ ] Confirm SSH access works
- [ ] Schedule maintenance window
- [ ] Have rollback plan ready

---

## Migration Approach

**Recommended:** Clean cut migration (from MIGRATION-PLAN.md)

1. ✅ Test FortiGate VLAN 4 with laptop (verify DHCP/internet)
2. 🔧 Change CloudKey IP to 172.16.4.9
3. 🔧 Change CloudKey port VLAN to CBS-Corp (4)
4. 🔌 Switch from SonicWall to FortiGate
5. 🔄 Power cycle all switches one by one
6. ✅ Verify all devices reconnect
7. 💾 Create backup of new configuration

**Estimated Time:** 2-4 hours depending on number of devices

---

## Important Notes

### CMMC Compliance
- FortiGate VLANs are isolated by default (CMMC requirement)
- Inter-VLAN routing policies exist but should be removed after migration if not needed
- Document any security changes made during migration

### Device Information
- **CloudKey Model:** UCK-G2-PLUS
- **Hostname:** CBS-UCKGen2
- **UniFi OS:** 4.4.3
- **Network App:** 10.0.160
- **SSH User:** root

### Access Requirements
- SSH access to CloudKey (tested and working)
- FortiGate admin access (https://172.16.4.1)
- UniFi Controller access
- Physical access to switches for power cycling

---

## Support Resources

### Documentation
- FortiGate CMMC Setup: See parent folder (../CONTEXT.md)
- FortiGate Admin Guide: FortiOS 7.4.9 documentation
- UniFi Documentation: https://help.ui.com

### Contact
- Fortinet Support: 1-866-648-4638
- Ubiquiti Support: https://help.ui.com
- FortiGate Serial: FGT60FTK24031122

---

## File History

| File | Created | Last Updated | Purpose |
|------|---------|--------------|---------|
| MIGRATION-PLAN.md | 2026-01-09 | 2026-01-09 | Comprehensive migration planning and history |
| QUICK-REFERENCE.md | 2026-01-09 | 2026-01-09 | Command reference and quick lookup |
| TROUBLESHOOTING.md | 2026-01-09 | 2026-01-09 | Issue resolution and diagnostics |
| README.md | 2026-01-09 | 2026-01-09 | This file - documentation overview |

---

## Contributing to Documentation

When you attempt the migration again:

1. **Update MIGRATION-PLAN.md:**
   - Add new attempts to "What We Tried" section
   - Update "Current State" at top
   - Add any new lessons learned

2. **Update TROUBLESHOOTING.md:**
   - Add any new issues encountered
   - Document solutions that worked

3. **Create Backup:**
   - Save configuration backups with date
   - Export switch port configs before changes

4. **Git Commit:**
   - Commit documentation updates
   - Include summary of attempt in commit message

---

## Next Steps

1. Review [MIGRATION-PLAN.md](MIGRATION-PLAN.md) completely
2. Answer "Questions Before Next Attempt" section
3. Complete "Next Session Checklist"
4. Schedule maintenance window
5. Have [QUICK-REFERENCE.md](QUICK-REFERENCE.md) and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) available during migration
6. Follow recommended approach step-by-step
7. Document what happens for future reference

---

**Good luck with the migration!**

Remember: Take your time, test with one device first, and have a clear rollback plan. Better to pause and regroup than to force through problems.

---

**Created:** January 9, 2026
**Documentation Version:** 1.0
**Status:** Ready for next migration attempt
