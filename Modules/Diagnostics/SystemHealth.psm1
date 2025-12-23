<#
.SYNOPSIS
    System Health and Hardware diagnostic checks

.DESCRIPTION
   Implements 10 core system health diagnostics
#>

function Get-SystemUptime {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $os = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_OperatingSystem
        }
        
        $bootTime = $os.LastBootUpTime
        $uptime = (Get-Date) - $bootTime
        
        $status = if ($uptime.TotalDays -gt 30) { 'Critical' } elseif ($uptime.TotalDays -gt 14) { 'Warning' } else { 'OK' }
        
        return [PSCustomObject]@{
            Check             = 'System Uptime'
            Value             = "$([Math]::Round($uptime.TotalDays, 1)) days (Last boot: $bootTime)"
            Status            = $status
            Severity          = $status
            RemediationAction = if ($status -eq 'Critical') { 'Reboot' } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'System Uptime'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-DiskSpaceAnalysis {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $disks = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_LogicalDisk -Filter "DriveType=3"
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_LogicalDisk -Filter "DriveType=3"
        }
        
        $results = @()
        foreach ($disk in $disks) {
            $freePercent = ($disk.FreeSpace / $disk.Size) * 100
            $freeGB = [Math]::Round($disk.FreeSpace / 1GB, 2)
            $totalGB = [Math]::Round($disk.Size / 1GB, 2)
            
            $status = if ($freePercent -lt 5) { 'Critical' } elseif ($freePercent -lt 10) { 'Warning' } else { 'OK' }
            
            $results += [PSCustomObject]@{
                Check             = "Disk Space - $($disk.DeviceID)"
                Value             = "$freeGB GB free of $totalGB GB ($([Math]::Round($freePercent, 1))%)"
                Status            = $status
                Severity          = $status
                RemediationAction = if ($status -ne 'OK') { 'DiskCleanup' } else { $null }
            }
        }
        
        return $results
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'Disk Space'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-SMARTStatus {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $drives = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_DiskDrive
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_DiskDrive
        }
        
        $results = @()
        foreach ($drive in $drives) {
            $status = if ($drive.Status -eq 'OK') { 'OK' } else { 'Critical' }
            
            $results += [PSCustomObject]@{
                Check             = "SMART Status - $($drive.Model)"
                Value             = $drive.Status
                Status            = $status
                Severity          = $status
                RemediationAction = if ($status -eq 'Critical') { 'Replace Drive' } else { $null }
            }
        }
        
        return $results
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'SMART Status'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-CPULoad {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $cpu = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_Processor
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Processor
        }
        
        $loadPercent = ($cpu | Measure-Object -Property LoadPercentage -Average).Average
        $status = if ($loadPercent -gt 90) { 'Critical' } elseif ($loadPercent -gt 75) { 'Warning' } else { 'OK' }
        
        return [PSCustomObject]@{
            Check             = 'CPU Load'
            Value             = "$loadPercent%"
            Status            = $status
            Severity          = $status
            RemediationAction = if ($status -eq 'Critical') { 'KillProcess' } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'CPU Load'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-MemoryUtilization {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $os = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_OperatingSystem
        }
        
        $totalGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedGB = $totalGB - $freeGB
        $usedPercent = ($usedGB / $totalGB) * 100
        
        $status = if ($usedPercent -gt 95) { 'Critical' } elseif ($usedPercent -gt 85) { 'Warning' } else { 'OK' }
        
        return [PSCustomObject]@{
            Check             = 'Memory Utilization'
            Value             = "$usedGB GB / $totalGB GB ($([Math]::Round($usedPercent, 1))%)"
            Status            = $status
            Severity          = $status
            RemediationAction = if ($status -eq 'Critical') { 'KillProcess' } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'Memory Utilization'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-ServiceHealth {
    param([string]$ComputerName, [CimSession]$CimSession, [array]$CriticalServices)
    
    if (-not $CriticalServices) {
        $CriticalServices = @('Spooler', 'WinRM', 'wuauserv', 'CcmExec')
    }
    
    $results = @()
    
    foreach ($serviceName in $CriticalServices) {
        try {
            $service = if ($CimSession) {
                Get-CimInstance -CimSession $CimSession -ClassName Win32_Service -Filter "Name='$serviceName'"
            }
            else {
                Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Service -Filter "Name='$serviceName'"
            }
            
            if ($service) {
                $status = if ($service.State -eq 'Running' -and $service.StartMode -in @('Auto', 'Automatic')) {
                    'OK'
                }
                elseif ($service.State -eq 'Stopped') {
                    'Critical'
                }
                else {
                    'Warning'
                }
                
                $results += [PSCustomObject]@{
                    Check             = "Service - $serviceName"
                    Value             = "State: $($service.State), StartMode: $($service.StartMode)"
                    Status            = $status
                    Severity          = $status
                    RemediationAction = if ($status -eq 'Critical') { "StartService:$serviceName" } else { $null }
                }
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Check             = "Service - $serviceName"
                Value             = "Not found or error"
                Status            = 'Warning'
                Severity          = 'Warning'
                RemediationAction = $null
            }
        }
    }
    
    return $results
}

function Get-BatteryHealth {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $battery = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_Battery
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Battery
        }
        
        if ($battery) {
            $designCapacity = $battery.DesignCapacity
            $fullChargeCapacity = $battery.FullChargeCapacity
            
            if ($designCapacity -and $fullChargeCapacity) {
                $health = ($fullChargeCapacity / $designCapacity) * 100
                $status = if ($health -lt 50) { 'Critical' } elseif ($health -lt 70) { 'Warning' } else { 'OK' }
                
                return [PSCustomObject]@{
                    Check             = 'Battery Health'
                    Value             = "$([Math]::Round($health, 1))% capacity remaining"
                    Status            = $status
                    Severity          = $status
                    RemediationAction = if ($status -eq 'Critical') { 'Replace Battery' } else { $null }
                }
            }
        }
        
        return [PSCustomObject]@{
            Check             = 'Battery Health'
            Value             = 'No battery detected (Desktop)'
            Status            = 'N/A'
            Severity          = 'Info'
            RemediationAction = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'Battery Health'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-PendingReboot {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $pendingReboot = $false
        $reasons = @()
        
        # Check various registry keys
        $regChecks = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
            'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
        )
        
        # For remote checks, use Invoke-Command
        $scriptBlock = {
            $pending = $false
            $reasons = @()
            
            if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
                $pending = $true
                $reasons += 'Component Based Servicing'
            }
            
            if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
                $pending = $true
                $reasons += 'Windows Update'
            }
            
            $fileRename = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
            if ($fileRename) {
                $pending = $true
                $reasons += 'File Rename Operations'
            }
            
            return @{
                Pending = $pending
                Reasons = $reasons -join ', '
            }
        }
        
        if ($ComputerName) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $result = & $scriptBlock
        }
        
        $status = if ($result.Pending) { 'Warning' } else { 'OK' }
        
        return [PSCustomObject]@{
            Check             = 'Pending Reboot'
            Value             = if ($result.Pending) { "Yes - $($result.Reasons)" } else { 'No' }
            Status            = $status
            Severity          = $status
            RemediationAction = if ($result.Pending) { 'Reboot' } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'Pending Reboot'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-TimeSyncStatus {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $scriptBlock = {
            $w32tm = w32tm /query /status
            $offset = $w32tm | Select-String 'Last Successful Sync Time' -Context 0, 3 | Out-String
            
            # Get current time
            $localTime = Get-Date
            
            # Query Domain Controller time
            try {
                $dc = (Get-ADDomainController -Discover).HostName
                $dcTime = Invoke-Command -ComputerName $dc -ScriptBlock { Get-Date } -ErrorAction Stop
                
                $drift = ($localTime - $dcTime).TotalSeconds
                
                return @{
                    Drift   = [Math]::Abs($drift)
                    Details = "Local: $localTime, DC: $dcTime"
                }
            }
            catch {
                return @{
                    Drift   = 0
                    Details = "Unable to query DC time"
                }
            }
        }
        
        if ($ComputerName) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $result = & $scriptBlock
        }
        
        $status = if ($result.Drift -gt 300) { 'Critical' } elseif ($result.Drift -gt 60) { 'Warning' } else { 'OK' }
        
        return [PSCustomObject]@{
            Check             = 'Time Synchronization'
            Value             = "$([Math]::Round($result.Drift, 1)) seconds drift - $($result.Details)"
            Status            = $status
            Severity          = $status
            RemediationAction = if ($status -ne 'OK') { 'SyncTime' } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'Time Synchronization'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Get-DeviceManagerErrors {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $devices = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
        }
        
        if ($devices) {
            $errorCount = ($devices | Measure-Object).Count
            $deviceNames = ($devices | Select-Object -First 3 -ExpandProperty Name) -join ', '
            
            return [PSCustomObject]@{
                Check             = 'Device Manager Errors'
                Value             = "$errorCount device(s) with errors: $deviceNames..."
                Status            = 'Warning'
                Severity          = 'Warning'
                RemediationAction = 'UpdateDrivers'
            }
        }
        else {
            return [PSCustomObject]@{
                Check             = 'Device Manager Errors'
                Value             = 'No errors detected'
                Status            = 'OK'
                Severity          = 'Info'
                RemediationAction = $null
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check             = 'Device Manager Errors'
            Value             = "Error: $_"
            Status            = 'Error'
            Severity          = 'Error'
            RemediationAction = $null
        }
    }
}

function Invoke-SystemHealthChecks {
    <#
    .SYNOPSIS
        Runs all system health checks
    #>
    param(
        [string]$ComputerName,
        [CimSession]$CimSession,
        [array]$CriticalServices
    )
    
    $results = @()
    
    $results += Get-SystemUptime -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-DiskSpaceAnalysis -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-SMARTStatus -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-CPULoad -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-MemoryUtilization -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-ServiceHealth -ComputerName $ComputerName -CimSession $CimSession -CriticalServices $CriticalServices
    $results += Get-BatteryHealth -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-PendingReboot -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-TimeSyncStatus -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-DeviceManagerErrors -ComputerName $ComputerName -CimSession $CimSession
    
    return $results
}

Export-ModuleMember -Function Invoke-SystemHealthChecks, Get-*
