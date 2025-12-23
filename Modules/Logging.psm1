<#
.SYNOPSIS
    Centralized logging module for EMS

.DESCRIPTION
    Provides structured logging with severity levels and SIEM compatibility
#>

function Write-EMSLog {
    <#
    .SYNOPSIS
        Writes structured log entry
    
    .PARAMETER Message
        Log message
    
    .PARAMETER Severity
        Severity level (Info, Warning, Error, Success)
    
    .PARAMETER Category
        Log category (Authentication, Scan, Remediation, etc.)
    
    .PARAMETER Target
        Target system if applicable
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Severity = 'Info',
        
        [string]$Category = 'General',
        
        [string]$Target = ''
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $user = if ($Global:CurrentUser) { $Global:CurrentUser } else { $env:USERNAME }
    $computer = $env:COMPUTERNAME
    
    $logEntry = [PSCustomObject]@{
        Timestamp = $timestamp
        Computer  = $computer
        User      = $user
        Severity  = $Severity
        Category  = $Category
        Target    = $Target
        Message   = $Message
    }
    
    # Console output with color
    $color = switch ($Severity) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Success' { 'Green' }
        default { 'White' }
    }
    
    Write-Host "[$timestamp] [$Severity] $Message" -ForegroundColor $color
    
    # File logging
    try {
        $logDir = Join-Path $PSScriptRoot "..\Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $logFile = Join-Path $logDir "EMS_$(Get-Date -Format 'yyyyMMdd').csv"
        $logEntry | Export-Csv -Path $logFile -Append -NoTypeInformation
        
    }
    catch {
        Write-Warning "Failed to write log file: $_"
    }
}

function Export-AuditTrail {
    <#
    .SYNOPSIS
        Exports audit trail in SIEM-compatible format
    
    .PARAMETER StartDate
        Start date for export
    
    .PARAMETER EndDate
        End date for export
    
    .PARAMETER OutputPath
        Output file path
    #>
    param(
        [datetime]$StartDate = (Get-Date).AddDays(-7),
        [datetime]$EndDate = (Get-Date),
        [string]$OutputPath
    )
    
    try {
        $logDir = Join-Path $PSScriptRoot "..\Logs"
        
        if (-not (Test-Path $logDir)) {
            Write-Warning "No logs found"
            return
        }
        
        # Collect all log files in date range
        $logs = @()
        
        Get-ChildItem -Path $logDir -Filter "EMS_*.csv" | ForEach-Object {
            $logDate = [datetime]::ParseExact($_.BaseName.Replace('EMS_', ''), 'yyyyMMdd', $null)
            
            if ($logDate -ge $StartDate -and $logDate -le $EndDate) {
                $logs += Import-Csv $_.FullName
            }
        }
        
        if ($logs.Count -eq 0) {
            Write-Warning "No logs found in specified date range"
            return
        }
        
        # Export consolidated logs
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $OutputPath = Join-Path $logDir "AuditTrail_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        }
        
        $logs | Export-Csv -Path $OutputPath -NoTypeInformation
        
        Write-Host "Exported $($logs.Count) log entries to: $OutputPath" -ForegroundColor Green
        
        return $OutputPath
        
    }
    catch {
        Write-Error "Failed to export audit trail: $_"
    }
}

function Get-LogAnalytics {
    <#
    .SYNOPSIS
        Analyzes historical logs
    
    .PARAMETER Days
        Number of days to analyze
    
    .RETURNS
        Analytics summary
    #>
    param(
        [int]$Days = 7
    )
    
    try {
        $logDir = Join-Path $PSScriptRoot "..\Logs"
        
        if (-not (Test-Path $logDir)) {
            Write-Warning "No logs found"
            return
        }
        
        $startDate = (Get-Date).AddDays(-$Days)
        $logs = @()
        
        Get-ChildItem -Path $logDir -Filter "EMS_*.csv" | ForEach-Object {
            try {
                $logDate = [datetime]::ParseExact($_.BaseName.Replace('EMS_', ''), 'yyyyMMdd', $null)
                
                if ($logDate -ge $startDate) {
                    $logs += Import-Csv $_.FullName
                }
            }
            catch {
                # Skip invalid files
            }
        }
        
        if ($logs.Count -eq 0) {
            Write-Warning "No logs found for analysis"
            return
        }
        
        # Calculate analytics
        $analytics = [PSCustomObject]@{
            TotalEntries         = $logs.Count
            ErrorCount           = ($logs | Where-Object Severity -eq 'Error').Count
            WarningCount         = ($logs | Where-Object Severity -eq 'Warning').Count
            SuccessCount         = ($logs | Where-Object Severity -eq 'Success').Count
            TopUsers             = ($logs | Group-Object User | Sort-Object Count -Descending | Select-Object -First 5 Name, Count)
            TopTargets           = ($logs | Where-Object Target | Group-Object Target | Sort-Object Count -Descending | Select-Object -First 5 Name, Count)
            ByCategoryCategories = ($logs | Group-Object Category | Sort-Object Count -Descending | Select-Object Name, Count)
        }
        
        return $analytics
        
    }
    catch {
        Write-Error "Failed to analyze logs: $_"
    }
}

Export-ModuleMember -Function Write-EMSLog, Export-AuditTrail, Get-LogAnalytics
