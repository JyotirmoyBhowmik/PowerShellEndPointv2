# Enterprise Endpoint Monitoring System (EMS) - Installation Guide

**Version**: 1.0  
**Last Updated**: 2025-12-23

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Installation Steps](#installation-steps)
4. [Configuration](#configuration)
5. [Active Directory Setup](#active-directory-setup)
6. [Endpoint Preparation](#endpoint-preparation)
7. [Initial Testing](#initial-testing)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Software Requirements

#### Administrator Workstation
- **Operating System**: Windows 10 (1809+) or Windows 11
- **PowerShell**: Version 5.1 or later
- **.NET Framework**: 4.8 or later (pre-installed on Windows 10/11)
- **RSAT (Remote Server Administration Tools)**: Active Directory module
- **SCCM Console** (Optional): For enhanced user resolution via User Device Affinity

#### Target Endpoints
- **Operating System**: Windows 10, Windows 11, Windows Server 2016+
- **PowerShell Remoting**: Enabled (`Enable-PSRemoting`)
- **WinRM Service**: Running
- **Firewall Rules**: Ports 5985 (HTTP) and 5986 (HTTPS) open

### Network Requirements

- **DNS**: Fully functional DNS resolution for all endpoints
- **Active Directory**: Domain-joined workstations and servers
- **MPLS/WAN**: Minimum 512 Kbps bandwidth for remote sites
- **Firewall**: 
  - Inbound: WinRM (TCP 5985/5986)
  - Outbound: HTTPS (TCP 443) for SCCM communication

### Permissions Requirements

The user running EMS must have:
- **Local Administrator** rights on the admin workstation
- **Domain User** account
- **Member** of the `EMS_Admins` security group (created during setup)
- **Read permissions** on AD computer objects
- **WinRM access** to target endpoints
- **LAPS Read** permissions (if using LAPS auditing)

---

## System Requirements

### Minimum Hardware (Admin Workstation)

- **CPU**: Dual-core 2.0 GHz
- **RAM**: 4 GB
- **Disk Space**: 500 MB
- **Network**: 100 Mbps

### Recommended Hardware (Admin Workstation)

- **CPU**: Quad-core 3.0 GHz or higher
- **RAM**: 8 GB or higher
- **Disk Space**: 2 GB (for logs and exports)
- **Network**: Gigabit Ethernet

---

## Installation Steps

### Step 1: Download and Extract

1. Download the EMS package to your admin workstation
2. Extract to: `C:\Program Files\EMS\` or preferred location
3. Verify all files are present:

```
C:\Program Files\EMS\
├── Invoke-EMS.ps1
├── MainWindow.xaml
├── Config\
│   └── EMSConfig.json
├── Modules\
│   ├── Authentication.psm1
│   ├── Logging.psm1
│   ├── TopologyDetector.psm1
│   ├── InputBroker.psm1
│   ├── UserResolution.psm1
│   ├── DataFetcher.psm1
│   ├── Remediation.psm1
│   ├── BulkProcessor.psm1
│   └── Diagnostics\
│       ├── SystemHealth.psm1
│       ├── SecurityPosture.psm1
│       ├── NetworkDiagnostics.psm1
│       ├── SoftwareCompliance.psm1
│       └── UserExperience.psm1
└── README.md
```

### Step 2: Set Execution Policy

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

**Security Note**: This allows locally-created scripts to run. For enhanced security in production, consider signing the scripts with a code-signing certificate.

### Step 3: Install Required PowerShell Modules

```powershell
# Install Active Directory module (if not present)
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Verify installation
Get-Module -ListAvailable -Name ActiveDirectory

# Optional: Install SCCM Console (for User Device Affinity)
# Follow your organization's SCCM deployment guide
```

### Step 4: Create Logs Directory

```powershell
New-Item -Path "C:\Program Files\EMS\Logs" -ItemType Directory -Force
```

---

## Configuration

### Step 1: Customize Network Topology

Edit `Config\EMSConfig.json`:

```json
{
  "Topology": {
    "HOSubnets": [
      "10.192.10.0/23",
      "10.192.15.0/24",
      "10.192.16.0/24",
      "10.192.17.0/24",
      "10.192.18.0/24"
    ],
    "RemoteSubnets": [
      "10.192.13.0/24",
      "10.192.20.0/24",
      "10.192.21.0/24",
      "10.192.22.0/24",
      "10.192.25.0/24",
      "10.192.30.0/24",
      "10.192.35.0/24",
      "10.192.38.0/24"
    ],
    "HOThrottleLimit": 40,
    "RemoteThrottleLimit": 4,
    "CIMSessionTimeout": 15,
    "InvokeCommandTimeout": 30
  }
}
```

**Action Required**: Update subnet ranges to match your actual network topology.

### Step 2: Configure Security Settings

Update the security section:

```json
{
  "Security": {
    "AdminGroup": "EMS_Admins",
    "AuditLogPath": "\\\\FileServer\\Logs\\EMS",
    "EnableRemediation": true,
    "RequireConfirmation": true
  }
}
```

**Recommendations**:
- Set `AuditLogPath` to a network share for centralized logging
- Keep `RequireConfirmation: true` for production safety
- Set `EnableRemediation: false` during pilot testing

### Step 3: Configure User Resolution

```json
{
  "UserResolution": {
    "UseSCCM": true,
    "SCCMSiteServer": "SCCM01.corp.local",
    "FallbackToDC": true,
    "EventLogTimeWindowHours": 24,
    "TimeoutSeconds": 30
  }
}
```

**Action Required**:
- Set `SCCMSiteServer` to your actual SCCM server
- Set `UseSCCM: false` if SCCM is not available

### Step 4: Configure Diagnostic Thresholds

```json
{
  "Diagnostics": {
    "UptimeThresholdDays": 30,
    "DiskSpaceWarningPercent": 15,
    "DiskSpaceCriticalPercent": 5,
    "CPUWarningPercent": 75,
    "CPUCriticalPercent": 90,
    "MemoryWarningPercent": 85,
    "MemoryCriticalPercent": 95,
    "TempFolderSizeWarningGB": 1,
    "ProfileSizeWarningGB": 5
  }
}
```

**Customization**: Adjust thresholds based on your environment's baseline.

### Step 5: Configure Blacklisted Software

```json
{
  "BlacklistedSoftware": [
    "Dropbox",
    "Steam",
    "Tor Browser",
    "TeamViewer",
    "AnyDesk",
    "BitTorrent",
    "uTorrent"
  ]
}
```

**Action Required**: Add your organization's prohibited applications.

---

## Active Directory Setup

### Step 1: Create Security Group

Open **Active Directory Users and Computers** as Domain Admin:

```powershell
# PowerShell method
Import-Module ActiveDirectory

New-ADGroup -Name "EMS_Admins" `
            -GroupCategory Security `
            -GroupScope Global `
            -Path "OU=Security Groups,DC=corp,DC=local" `
            -Description "Users authorized to run Enterprise Endpoint Monitoring System"
```

### Step 2: Add Users to Group

```powershell
Add-ADGroupMember -Identity "EMS_Admins" -Members "jsmith", "mjones", "tadmin"
```

**Verification**:
```powershell
Get-ADGroupMember -Identity "EMS_Admins"
```

### Step 3: Configure LAPS Permissions (Optional)

If using LAPS auditing, grant read permissions:

```powershell
# Grant EMS_Admins read access to LAPS password attribute
Set-AdmPwdReadPasswordPermission -OrgUnit "OU=Workstations,DC=corp,DC=local" `
                                 -AllowedPrincipals "EMS_Admins"
```

---

## Endpoint Preparation

### Step 1: Enable PowerShell Remoting

Run on each target endpoint (or deploy via GPO):

```powershell
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Restart-Service WinRM
```

**GPO Deployment**:
1. **Computer Configuration** → **Policies** → **Administrative Templates**
2. **Windows Components** → **Windows Remote Management (WinRM)** → **WinRM Service**
3. Enable: **Allow remote server management through WinRM**
4. Set IPv4/IPv6 filters to `*` or your subnet ranges

### Step 2: Configure Firewall Rules

```powershell
# Allow WinRM HTTP
New-NetFirewallRule -DisplayName "WinRM HTTP-In" `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort 5985 `
                    -Action Allow

# Allow WinRM HTTPS (recommended for production)
New-NetFirewallRule -DisplayName "WinRM HTTPS-In" `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort 5986 `
                    -Action Allow
```

**GPO Deployment**: 
- Use **Computer Configuration** → **Policies** → **Windows Settings** → **Security Settings** → **Windows Firewall**

### Step 3: Test Connectivity

From admin workstation:

```powershell
# Test WinRM
Test-WSMan -ComputerName "WKSTN-HO-01"

# Test CIM
Test-Connection -ComputerName "WKSTN-HO-01" -Count 2

# Test credentials
Enter-PSSession -ComputerName "WKSTN-HO-01" -Credential (Get-Credential)
```

---

## Initial Testing

### Step 1: Launch EMS

```powershell
cd "C:\Program Files\EMS"
.\Invoke-EMS.ps1
```

**Expected Result**: WPF window opens with login overlay.

### Step 2: Authenticate

1. Enter your domain credentials (e.g., `CORP\jsmith`)
2. Enter password
3. Click **Login**

**Expected Result**: Login overlay disappears, main dashboard appears.

**Troubleshooting Login Failures**:
- Verify user is in `EMS_Admins` group: `Get-ADGroupMember -Identity "EMS_Admins"`
- Check Activity Log for error details
- Verify domain connectivity: `Test-ComputerSecureChannel`

### Step 3: Single Endpoint Scan

1. In the **Target** field, enter a test hostname: `WKSTN-HO-01`
2. Click **Scan Endpoint**

**Expected Result**:
- Status bar shows "Processing target..."
- Results appear in **Dashboard** tab within 5-30 seconds
- Health Score is calculated
- Categorized diagnostic results populate tabs

### Step 4: Bulk Import Test

1. Create test CSV file: `C:\temp\test_targets.csv`

```csv
Hostname
WKSTN-HO-01
WKSTN-HO-02
WKSTN-RM-10
```

2. Click **📁 Load Target List**
3. Select the CSV file

**Expected Result**:
- System imports and validates targets
- Splits into HO/Remote queues
- Processes with appropriate throttling
- Results populate progressively

### Step 5: User Resolution Test

1. Enter a User ID: `jsmith`
2. Click **Scan Endpoint**

**Expected Result**:
- System queries SCCM for User Device Affinity
- Falls back to Event Log search if SCCM unavailable
- Returns hostname and scans endpoint

### Step 6: Export Test

1. After scanning, click **📊 Export Report**
2. Save to: `C:\temp\EMS_Report.csv`

**Expected Result**: CSV file created with all diagnostic results.

---

## Troubleshooting

### Issue: "Access Denied" on Login

**Symptoms**: Login fails with "Access Denied" or "User not authorized"

**Solutions**:
1. Verify user is in `EMS_Admins` group
2. Check config file has correct group name
3. Run `gpupdate /force` on admin workstation
4. Log out and back in to refresh group membership

### Issue: "Target Offline" Errors

**Symptoms**: All endpoints show as offline or unreachable

**Solutions**:
1. Verify WinRM is enabled on target:
   ```powershell
   Test-WSMan -ComputerName WKSTN-HO-01
   ```
2. Check firewall rules (ports 5985/5986)
3. Verify DNS resolution: `Resolve-DnsName WKSTN-HO-01`
4. Test manual connection:
   ```powershell
   Enter-PSSession -ComputerName WKSTN-HO-01
   ```

### Issue: SCCM User Resolution Fails

**Symptoms**: User ID scans time out or return "Unable to resolve"

**Solutions**:
1. Verify SCCM site server configured correctly
2. Check if ConfigurationManager module is installed:
   ```powershell
   Get-Module -ListAvailable ConfigurationManager
   ```
3. Set `UseSCCM: false` in config to use Event Log fallback
4. Verify network connectivity to SCCM server

### Issue: Slow MPLS Scans

**Symptoms**: Remote site scans take >2 minutes per endpoint

**Solutions**:
1. Increase `CIMSessionTimeout` in config (try 30s)
2. Reduce `RemoteThrottleLimit` to 3 (less network congestion)
3. Increase `DelayBetweenRemoteBatchesSeconds` to 10
4. Verify MPLS link bandwidth with network team

### Issue: GUI Freezes During Scan

**Symptoms**: Window becomes unresponsive, shows "Not Responding"

**Solutions**:
1. This indicates runspace pool issue
2. Restart application
3. Scan fewer targets simultaneously
4. Check logs for error stack traces

### Issue: "Module Not Found" Errors

**Symptoms**: Red errors about missing .psm1 files

**Solutions**:
1. Verify all files extracted correctly
2. Check `Modules` folder structure matches installation
3. Run from correct directory: `cd "C:\Program Files\EMS"`
4. Check execution policy: `Get-ExecutionPolicy`

---

## Log File Locations

| Log Type | Default Location | Purpose |
|----------|------------------|---------|
| Authentication | `Logs\AuthAudit_YYYYMM.csv` | Login attempts |
| Activity | `Logs\EMS_YYYYMMDD.csv` | All operations |
| Remediation | `Logs\RemediationAudit_YYYYMM.csv` | Fix actions |
| Error | `Logs\Errors_YYYYMMDD.log` | Exception stack traces |

---

## Security Hardening (Production)

### Recommended Post-Installation Steps

1. **Code Signing**: Sign all `.ps1` and `.psm1` files with your organization's code-signing certificate
   ```powershell
   Set-AuthenticodeSignature -FilePath .\Invoke-EMS.ps1 -Certificate $cert
   ```

2. **Constrained Endpoints**: Use JEA (Just Enough Administration) for remote connections
   ```powershell
   Register-PSSessionConfiguration -Name EMS_Restricted
   ```

3. **HTTPS WinRM**: Configure certificate-based authentication
   ```powershell
   winrm quickconfig -transport:https
   ```

4. **Audit Logging to SIEM**: Configure centralized logging
   - Set `AuditLogPath` to network share
   - Configure SIEM to ingest CSV logs

5. **Least Privilege**: Create dedicated service account with minimum permissions

---

## Deployment Checklist

Use this checklist for each installation:

- [ ] PowerShell 5.1+ installed
- [ ] .NET Framework 4.8+ installed
- [ ] RSAT Active Directory module installed
- [ ] Execution policy set to RemoteSigned
- [ ] EMS files extracted to installation directory
- [ ] Logs directory created
- [ ] Config file customized (subnets, SCCM server, thresholds)
- [ ] `EMS_Admins` AD security group created
- [ ] Admin users added to security group
- [ ] WinRM enabled on target endpoints (or GPO deployed)
- [ ] Firewall rules configured (ports 5985/5986)
- [ ] Connectivity tested with `Test-WSMan`
- [ ] Single endpoint scan successful
- [ ] Bulk import tested
- [ ] Export functionality verified
- [ ] Logs reviewed for errors
- [ ] Documentation provided to admin team

---

## Support and Maintenance

### Regular Maintenance Tasks

**Weekly**:
- Review error logs
- Archive old CSV reports
- Verify SCCM connectivity

**Monthly**:
- Update blacklisted software list
- Review audit logs for unauthorized access
- Test failover scenarios (SCCM offline, DC unavailable)

**Quarterly**:
- Update diagnostic thresholds based on trends
- Review and update subnet topology
- Training refresher for new admins

### Getting Help

1. **Documentation**: Review README.md and this installation guide
2. **Logs**: Check `Logs\` directory for detailed error messages
3. **Testing**: Use PowerShell ISE to test individual module functions
4. **Community**: Consult PowerShell community forums for WPF/Runspace issues

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-23 | Initial release with 60+ diagnostic checks |

---

**Document End**

For usage instructions and feature details, see [README.md](README.md).  
For technical implementation details, see [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md).  
For SoW compliance verification, see [SOW_VERIFICATION_REPORT.md](SOW_VERIFICATION_REPORT.md).
