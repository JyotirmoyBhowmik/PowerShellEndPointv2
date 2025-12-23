# Enterprise Distributed Endpoint Monitoring System (EMS)

## Overview

The Enterprise Distributed Endpoint Monitoring System (EMS) is a sophisticated PowerShell-based WPF application designed for network administrators to perform comprehensive diagnostics and remediation across hybrid network topologies.

## Features

### Core Capabilities
- **60+ Diagnostic Checks** across 5 categories:
  - System Health & Hardware (10 checks)
  - Security Posture & Forensics (20 checks)
  - Network Diagnostics (10 checks)
  - Software & Compliance (10 checks)
  - User Experience (10 checks)

- **Network Topology Awareness**:
  - Automatic detection of Head Office (HO) vs Remote/MPLS sites
  - Topology-aware throttling to prevent MPLS saturation
  - Optimized protocols: Invoke-Command for HO, CIM Sessions for MPLS

- **Multi-Modal Input**:
  - Single hostname/IP scan
  - User ID resolution (via SCCM or Event Logs)
  - Bulk CSV import with AD validation

- **Interactive Remediation**:
  - Service restart/start
  - Process termination
  - Disk cleanup operations
  - GPO refresh
  - Role-Based Access Control (RBAC)
  - Comprehensive audit logging

### Security Features
- Active Directory authentication
- Group membership authorization (EMS_Admins)
- Audit trail for all authentication and remediation actions
- SecureString password handling

## System Requirements

- **OS**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or later
- **Permissions**: Administrator rights
- **Network**: WinRM enabled on target endpoints
- **Optional**: SCCM for enhanced user resolution

## Quick Start

1. **Launch the Application**:
   ```powershell
   .\Invoke-EMS.ps1
   ```

2. **Authenticate**:
   - Enter domain credentials
   - Must be member of configured admin group (default: `EMS_Admins`)

3. **Scan a Single Endpoint**:
   - Enter hostname, IP, or User ID in the target field
   - Click "Scan Endpoint"

4. **Bulk Scan**:
   - Prepare a CSV file (see `sample_targets.csv`)
   - Click "📁 Load Target List"
   - System automatically splits into HO/Remote queues

5. **Remediation**:
   - View diagnostic results in categorized tabs
   - Click "Fix" buttons for actionable remediation
   - All actions are logged

## Configuration

Edit `Config\EMSConfig.json` to customize:

- **Topology**: Subnet definitions for HO vs Remote classification
- **Security**: Admin group name, audit log path
- **UserResolution**: SCCM settings, event log search parameters
- **Diagnostics**: Thresholds for disk space, uptime, CPU, memory
- **Remediation**: Enable/disable specific actions
- **BulkProcessing**: Throttle limits and batch sizes

## Architecture

### Dual-Queue Processing
- **HO Queue**: High concurrency (40 parallel threads)
- **Remote Queue**: Throttled (4 parallel threads with 5s delays between batches)

### User Resolution Strategies
1. **Primary**: SCCM User Device Affinity
2. **Fallback**: Event Log forensic correlation (Event ID 4624)
3. **Manual**: Prompt for hostname if automation fails

### Runspace Pool
- Asynchronous multi-threaded execution
- Prevents UI freezing during long-running operations
- Thread-safe synchronized hashtable for UI updates

## Diagnostic Modules

### System Health
- Uptime monitoring with reboot recommendations
- Disk space analysis with cleanup suggestions
- SMART drive health status
- CPU and memory utilization
- Critical service health checks
- Battery health (laptops)
- Pending reboot detection
- Time synchronization vs Domain Controller
- Device Manager error enumeration

### Security Posture
- Secure Boot verification
- LAPS password status
- Local administrator enumeration
- BitLocker encryption status
- USB device forensic history
- Firewall profile validation
- Anti-virus status
- UAC settings

### Network Diagnostics
- IP configuration and APIPA detection
- DNS resolution testing
- Latency to gateway and core
- Jitter and packet loss measurement
- NIC speed/duplex mismatch detection
- Active TCP connection summary
- Wi-Fi signal strength
- DHCP lease information
- ARP table poisoning detection

## Remediation Actions

All remediation actions require authorization and are audited:

| Issue | Remediation | Command |
|-------|-------------|---------|
| Service Stopped | Start Service | `Invoke-ServiceRemediation` |
| High CPU | Kill Process | `Invoke-ProcessRemediation` |
| Low Disk Space | Clear Temp Files | `Invoke-DiskRemediation` |
| GPO Mismatch | Force Update | `Invoke-GPORemediation` |
| Pending Reboot | Restart Computer | (with confirmation) |

## Logging & Auditing

### Authentication Log
- `Logs\AuthAudit_YYYYMM.csv`
- Records all login attempts (success/failure)

### Activity Log
- `Logs\EMS_YYYYMMDD.csv`
- All application actions and scan results

### Remediation Audit
- `Logs\RemediationAudit_YYYYMM.csv`
- Every remediation action with timestamp, user, target, result

## Bulk Import CSV Format

```csv
Hostname
WKSTN-HO-01
WKSTN-RM-10
10.192.10.50
```

Supported column names: `Hostname`, `ComputerName`, `Target`, `IP`, `Computer`, `Name`

## Troubleshooting

### "Access Denied" on Login
- Verify user is member of configured admin group
- Check `EMSConfig.json` for correct group name

### "Target Offline" Errors
- Verify WinRM is enabled: `Test-WSMan -ComputerName <target>`
- Check firewall rules for ports 5985/5986

### SCCM Resolution Fails
- Verify SCCM site server configuration
- Check if ConfigurationManager module is installed
- Falls back to Event Log search automatically

### Slow MPLS Scans
- Review `RemoteThrottleLimit` in configuration
- Increase if bandwidth allows, decrease if impacting VoIP/ERP

## Version

- **Version**: 1.0
- **Date**: 2025-12-23
- **Author**: Enterprise IT Team

## License

Internal use only - Enterprise proprietary software
