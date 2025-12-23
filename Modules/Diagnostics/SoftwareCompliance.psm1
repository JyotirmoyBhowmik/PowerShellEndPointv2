<#
.SYNOPSIS
    Software and compliance diagnostics module

.DESCRIPTION
    Implements 10 software inventory and compliance checks
#>

function Get-InstalledApplications {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $apps = @()
            
            # 32-bit apps
            $apps += Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
            
            # 64-bit apps
            $apps += Get-ItemProperty 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
            
            $apps = $apps | Where-Object DisplayName | Select-Object -Unique DisplayName, DisplayVersion, Publisher
            
            return ($apps | Measure-Object).Count
        }
        
        if ($ComputerName) {
            $count = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $count = & $scriptBlock
        }
        
        return [PSCustomObject]@{
            Check      = 'Installed Applications'
            Details    = "$count applications installed"
            Compliance = 'Info'
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Installed Applications'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Test-BlacklistedSoftware {
    param([string]$ComputerName, [array]$BlacklistedApps)
    
    if (-not $BlacklistedApps) {
        $BlacklistedApps = @('Dropbox', 'Steam', 'Tor Browser', 'TeamViewer', 'AnyDesk')
    }
    
    try {
        $scriptBlock = {
            param($blacklist)
            
            $apps = @()
            $apps += Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
            $apps += Get-ItemProperty 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
            
            $found = @()
            foreach ($app in $apps) {
                foreach ($banned in $blacklist) {
                    if ($app.DisplayName -like "*$banned*") {
                        $found += $app.DisplayName
                    }
                }
            }
            
            return $found
        }
        
        if ($ComputerName) {
            $foundApps = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList (, $BlacklistedApps)
        }
        else {
            $foundApps = & $scriptBlock -blacklist $BlacklistedApps
        }
        
        if ($foundApps) {
            return [PSCustomObject]@{
                Check      = 'Blacklisted Software'
                Details    = "Found: $($foundApps -join ', ')"
                Compliance = 'Critical'
            }
        }
        else {
            return [PSCustomObject]@{
                Check      = 'Blacklisted Software'
                Details    = 'No prohibited software detected'
                Compliance = 'OK'
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Blacklisted Software'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Get-OSBuildVersion {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $os = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_OperatingSystem
        }
        
        $version = $os.Version
        $build = $os.BuildNumber
        
        # Check if Windows 10/11 and get release ID
        $scriptBlock = {
            $releaseId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ReleaseId -ErrorAction SilentlyContinue).ReleaseId
            $displayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
            
            return @{
                ReleaseId      = $releaseId
                DisplayVersion = $displayVersion
            }
        }
        
        if ($ComputerName) {
            $releaseInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $releaseInfo = & $scriptBlock
        }
        
        $versionString = if ($releaseInfo.DisplayVersion) {
            "$($os.Caption) $($releaseInfo.DisplayVersion) (Build $build)"
        }
        elseif ($releaseInfo.ReleaseId) {
            "$($os.Caption) $($releaseInfo.ReleaseId) (Build $build)"
        }
        else {
            "$($os.Caption) (Build $build)"
        }
        
        return [PSCustomObject]@{
            Check      = 'OS Build Version'
            Details    = $versionString
            Compliance = 'OK'
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'OS Build Version'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Get-OfficeVersion {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $officePath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
            
            if (Test-Path $officePath) {
                $config = Get-ItemProperty $officePath -ErrorAction SilentlyContinue
                
                return @{
                    Version = $config.VersionToReport
                    Channel = $config.CDNBaseUrl
                    Found   = $true
                }
            }
            
            return @{ Found = $false }
        }
        
        if ($ComputerName) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $result = & $scriptBlock
        }
        
        if ($result.Found) {
            return [PSCustomObject]@{
                Check      = 'Office Version'
                Details    = "Version: $($result.Version)"
                Compliance = 'OK'
            }
        }
        else {
            return [PSCustomObject]@{
                Check      = 'Office Version'
                Details    = 'Microsoft Office not detected'
                Compliance = 'Info'
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Office Version'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Test-SCCMClientHealth {
    param([string]$ComputerName, [CimSession]$CimSession)
    
    try {
        $service = if ($CimSession) {
            Get-CimInstance -CimSession $CimSession -ClassName Win32_Service -Filter "Name='CcmExec'"
        }
        else {
            Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Service -Filter "Name='CcmExec'"
        }
        
        if ($service) {
            $status = if ($service.State -eq 'Running') { 'OK' } else { 'Critical' }
            
            return [PSCustomObject]@{
                Check      = 'SCCM Client Health'
                Details    = "Service State: $($service.State)"
                Compliance = $status
            }
        }
        else {
            return [PSCustomObject]@{
                Check      = 'SCCM Client Health'
                Details    = 'SCCM client not installed'
                Compliance = 'Warning'
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'SCCM Client Health'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Get-WindowsUpdateHistory {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $historyCount = $searcher.GetTotalHistoryCount()
            
            if ($historyCount -gt 0) {
                $history = $searcher.QueryHistory(0, [Math]::Min(5, $historyCount)) | 
                Select-Object -Property Title, Date
                
                return $history | ForEach-Object { "$($_.Title) - $($_.Date.ToString('yyyy-MM-dd'))" }
            }
            
            return @('No update history')
        }
        
        if ($ComputerName) {
            $updates = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $updates = & $scriptBlock
        }
        
        return [PSCustomObject]@{
            Check      = 'Windows Update History'
            Details    = $updates -join '; '
            Compliance = 'Info'
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Windows Update History'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Get-BrowserExtensions {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $extensions = @()
            
            # Chrome extensions
            $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
            if (Test-Path $chromePath) {
                $chromeExts = Get-ChildItem $chromePath -Directory
                $extensions += "Chrome: $($chromeExts.Count) extensions"
            }
            
            # Edge extensions
            $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions"
            if (Test-Path $edgePath) {
                $edgeExts = Get-ChildItem $edgePath -Directory
                $extensions += "Edge: $($edgeExts.Count) extensions"
            }
            
            if ($extensions.Count -eq 0) {
                return 'No browser extensions found'
            }
            
            return $extensions -join '; '
        }
        
        if ($ComputerName) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $result = & $scriptBlock
        }
        
        return [PSCustomObject]@{
            Check      = 'Browser Extensions'
            Details    = $result
            Compliance = 'Info'
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Browser Extensions'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Get-StartupPrograms {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $startupItems = @()
            
            # Registry Run keys
            $runKeys = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
            )
            
            foreach ($key in $runKeys) {
                if (Test-Path $key) {
                    $items = Get-ItemProperty $key -ErrorAction SilentlyContinue
                    $startupItems += $items.PSObject.Properties | Where-Object { $_.Name -notmatch 'PS' } | Select-Object -ExpandProperty Name
                }
            }
            
            # Startup folder
            $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
            if (Test-Path $startupFolder) {
                $startupItems += (Get-ChildItem $startupFolder).Name
            }
            
            return ($startupItems | Measure-Object).Count
        }
        
        if ($ComputerName) {
            $count = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $count = & $scriptBlock
        }
        
        return [PSCustomObject]@{
            Check      = 'Startup Programs'
            Details    = "$count startup items configured"
            Compliance = 'Info'
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Startup Programs'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Test-CertificateExpiry {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $certs = Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue
            $expired = $certs | Where-Object { $_.NotAfter -lt (Get-Date) }
            $expiringSoon = $certs | Where-Object { $_.NotAfter -gt (Get-Date) -and $_.NotAfter -lt (Get-Date).AddDays(30) }
            
            return @{
                Expired      = ($expired | Measure-Object).Count
                ExpiringSoon = ($expiringSoon | Measure-Object).Count
            }
        }
        
        if ($ComputerName) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $result = & $scriptBlock
        }
        
        $status = if ($result.Expired -gt 0) { 'Critical' } elseif ($result.ExpiringSoon -gt 0) { 'Warning' } else { 'OK' }
        
        return [PSCustomObject]@{
            Check      = 'Certificate Expiry'
            Details    = "Expired: $($result.Expired), Expiring Soon: $($result.ExpiringSoon)"
            Compliance = $status
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Certificate Expiry'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Get-EnvironmentVariables {
    param([string]$ComputerName)
    
    try {
        $scriptBlock = {
            $path = $env:PATH
            $pathCount = ($path -split ';').Count
            
            # Check for anomalies (very long PATH or suspicious entries)
            $suspicious = $path -match '(temp|downloads|appdata\\local\\temp)'
            
            return @{
                PathCount  = $pathCount
                Suspicious = $suspicious
            }
        }
        
        if ($ComputerName) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock
        }
        else {
            $result = & $scriptBlock
        }
        
        $status = if ($result.Suspicious) { 'Warning' } else { 'OK' }
        
        return [PSCustomObject]@{
            Check      = 'Environment Variables'
            Details    = "$($result.PathCount) PATH entries$(if ($result.Suspicious) { ' - Suspicious paths detected' })"
            Compliance = $status
        }
    }
    catch {
        return [PSCustomObject]@{
            Check      = 'Environment Variables'
            Details    = "Error: $_"
            Compliance = 'Error'
        }
    }
}

function Invoke-SoftwareCompliance {
    <#
    .SYNOPSIS
        Runs all software and compliance checks
    #>
    param(
        [string]$ComputerName,
        [CimSession]$CimSession,
        [array]$BlacklistedApps
    )
    
    $results = @()
    
    $results += Get-InstalledApplications -ComputerName $ComputerName
    $results += Test-BlacklistedSoftware -ComputerName $ComputerName -BlacklistedApps $BlacklistedApps
    $results += Get-OSBuildVersion -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-OfficeVersion -ComputerName $ComputerName
    $results += Test-SCCMClientHealth -ComputerName $ComputerName -CimSession $CimSession
    $results += Get-WindowsUpdateHistory -ComputerName $ComputerName
    $results += Get-BrowserExtensions -ComputerName $ComputerName
    $results += Get-StartupPrograms -ComputerName $ComputerName
    $results += Test-CertificateExpiry -ComputerName $ComputerName
    $results += Get-EnvironmentVariables -ComputerName $ComputerName
    
    return $results
}

Export-ModuleMember -Function Invoke-SoftwareCompliance, Get-*, Test-*
