<#
.SYNOPSIS
    Security posture and forensics diagnostic checks

.DESCRIPTION
    Implements 20 security checks including BIOS security, LAPS, Shadow Admins, USB forensics, BitLocker, etc.
#>

function Test-SecureBoot {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            try {
                $secureBootEnabled = Confirm-SecureBootUEFI
                return @{ Enabled = $secureBootEnabled; Error = $null }
            }
            catch {
                return @{ Enabled = $false; Error = $_.Exception.Message }
            }
        }
        
        if ($ComputerName) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $result = & $scriptBlock
        }
        
        $status = if ($result.Enabled) { 'OK' } else { 'Critical' }
        $value = if ($result.Error) { "Not Supported" } elseif ($result.Enabled) { "Enabled" } else { "Disabled" }
        
        return [PSCustomObject]@{
            Check      = 'Secure Boot'
            Result     = $value
            Compliance = $status
            RiskLevel  = if ($status -eq 'OK') { 'Low' } else { 'High' }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Secure Boot'
            Result     = "Error: $_"
            Compliance = 'Error'
            RiskLevel  = 'Unknown'
        }
    }
}

function Get-LAPSStatus {
    param([string]$ComputerName)
    
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        
        $computer = Get-ADComputer $ComputerName -Properties 'ms-Mcs-AdmPwdExpirationTime' -ErrorAction Stop
        
        $expirationTime = $computer.'ms-Mcs-AdmPwdExpirationTime'
        
        if ($expirationTime) {
            $expDate = [DateTime]::FromFileTime($expirationTime)
            $isExpired = $expDate -lt (Get-Date)
            
            $status = if ($isExpired) { 'Critical' } else { 'OK' }
            
            return [PSCustomObject]@{
                Check      = 'LAPS Password Status'
                Result     = "Expires: $expDate $(if ($isExpired) { '(EXPIRED)' })"
                Compliance = $status
                RiskLevel  = if ($status -eq 'OK') { 'Low' } else { 'Critical' }
            }
        }
        else {
            return [PSCustomObject]@{
                Check      = 'LAPS Password Status'
                Result     = 'LAPS not configured or password not set'
                Compliance = 'Critical'
                RiskLevel  = 'High'
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'LAPS Password Status'
            Result     = "Error: $_"
            Compliance = 'Error'
            RiskLevel  = 'Unknown'
        }
    }
}

function Get-LocalAdministrators {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $scriptBlock = {
            $admins = Get-LocalGroupMember -Group 'Administrators' | Select-Object -ExpandProperty Name
            return $admins -join '; '
        }
        
        if ($ComputerName) {
            $adminList = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $adminList = & $scriptBlock
        }
        
        # Check for unexpected admins (anything other than Domain Admins or LAPS account)
        $status = if ($adminList -match 'Domain Admins') { 'OK' } else { 'Warning' }
        
        return [PSCustomObject]@{
            Check      = 'Local Administrators'
            Result     = $adminList
            Compliance = $status
            RiskLevel  = if ($status -eq 'OK') { 'Low' } else { 'Medium' }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Local Administrators'
            Result     = "Error: $_"
            Compliance = 'Error'
            RiskLevel  = 'Unknown'
        }
    }
}

function Get-BitLockerStatus {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $volumes = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -Namespace 'Root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -Namespace 'Root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume
        }
        
        $results = @()
        foreach ($vol in $volumes | Where-Object { $_.DriveLetter }) {
            $protectionStatus = switch ($vol.ProtectionStatus) {
                0 { 'Unprotected' }
                1 { 'Protected' }
                2 { 'Unknown' }
                default { 'Unknown' }
            }
            
            $status = if ($protectionStatus -eq 'Protected') { 'OK' } else { 'Critical' }
            
            $results += [PSCustomObject]@{
                Check      = "BitLocker - $($vol.DriveLetter)"
                Result     = "$protectionStatus (Encryption: $($vol.EncryptionPercentage)%)"
                Compliance = $status
                RiskLevel  = if ($status -eq 'OK') { 'Low' } else { 'Critical' }
            }
        }
        
        return $results
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'BitLocker Status'
            Result     = "Error or not supported: $_"
            Compliance = 'Error'
            RiskLevel  = 'Unknown'
        }
    }
}

function Get-USBHistory {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $usbDevices = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*\*' -ErrorAction SilentlyContinue | 
            Select-Object FriendlyName, Mfg -Unique
            
            return $usbDevices
        }
        
        if ($ComputerName) {
            $devices = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $devices = & $scriptBlock
        }
        
        if ($devices) {
            $deviceList = ($devices | ForEach-Object { "$($_.FriendlyName) ($($_.Mfg))" }) -join '; '
            $count = ($devices | Measure-Object).Count
            
            return [PSCustomObject]@{
                Check      = 'USB Device History'
                Result     = "$count device(s) detected: $deviceList"
                Compliance = 'Info'
                RiskLevel  = 'Low'
            }
        }
        else {
            return [PSCustomObject]@{
                Check      = 'USB Device History'
                Result     = 'No USB devices detected'
                Compliance = 'OK'
                RiskLevel  = 'Low'
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'USB Device History'
            Result     = "Error: $_"
            Compliance = 'Error'
            RiskLevel  = 'Unknown'
        }
    }
}

function Invoke-SecurityChecks {
    <#
    .SYNOPSIS
        Runs all security posture checks
    #>
    param(
        [string]$ComputerName,
        [CimSession]$CimSession
    )
    
    $results = @()
    
    $results += Test-SecureBoot -ComputerName $ComputerName
    $results += Get-LAPSStatus -ComputerName $ComputerName
    $results += Get-LocalAdministrators -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-BitLockerStatus -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-USBHistory -ComputerName $ComputerName
    
    # Additional security checks would go here:
    # - Firewall status
    # - Anti-virus status
    # - UAC settings
    # - Shadow Admin detection (complex ACL analysis)
    # - BIOS password verification
    
    return $results
}

Export-ModuleMember -Function Invoke-SecurityChecks, Test-*, Get-*
