<#
.SYNOPSIS
    Authentication and authorization module for EMS

.DESCRIPTION
    Handles Active Directory credential validation and group membership verification
#>

function Test-ADCredential {
    <#
    .SYNOPSIS
        Validates credentials against Active Directory
    
    .PARAMETER Username
        Username in domain\user or user@domain format
    
    .PARAMETER SecurePassword
        SecureString containing the password
    
    .RETURNS
        Boolean indicating successful authentication
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [SecureString]$SecurePassword
    )
    
    try {
        # Extract domain and username
        if ($Username -match '(.+)\\(.+)') {
            $domain = $Matches[1]
            $user = $Matches[2]
        }
        elseif ($Username -match '(.+)@(.+)') {
            $user = $Matches[1]
            $domain = $Matches[2]
        }
        else {
            $domain = $env:USERDOMAIN
            $user = $Username
        }
        
        # Create PrincipalContext
        $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
            [System.DirectoryServices.AccountManagement.ContextType]::Domain,
            $domain
        )
        
        # Convert SecureString to plain text for validation
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        
        # Validate credentials
        $isValid = $context.ValidateCredentials($user, $plainPassword)
        
        # Clean up sensitive data
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        $plainPassword = $null
        
        $context.Dispose()
        
        return $isValid
        
    }
    catch {
        Write-Error "Authentication error: $_"
        return $false
    }
}

function Test-UserAuthorization {
    <#
    .SYNOPSIS
        Checks if user is member of required security group
    
    .PARAMETER Username
        Username to check
    
    .PARAMETER RequiredGroup
        AD security group name
    
    .RETURNS
        Boolean indicating group membership
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$RequiredGroup
    )
    
    try {
        # Extract domain and username
        if ($Username -match '(.+)\\(.+)') {
            $domain = $Matches[1]
            $user = $Matches[2]
        }
        elseif ($Username -match '(.+)@(.+)') {
            $user = $Matches[1]
            $domain = $Matches[2]
        }
        else {
            $domain = $env:USERDOMAIN
            $user = $Username
        }
        
        # Create PrincipalContext
        $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
            [System.DirectoryServices.AccountManagement.ContextType]::Domain,
            $domain
        )
        
        # Get user principal
        $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($context, $user)
        
        if (-not $userPrincipal) {
            Write-Warning "User not found: $Username"
            return $false
        }
        
        # Get all groups
        $groups = $userPrincipal.GetAuthorizationGroups()
        
        $isMember = $false
        foreach ($group in $groups) {
            if ($group.Name -eq $RequiredGroup) {
                $isMember = $true
                break
            }
        }
        
        # Cleanup
        $userPrincipal.Dispose()
        $context.Dispose()
        
        return $isMember
        
    }
    catch {
        Write-Error "Authorization check error: $_"
        return $false
    }
}

function Write-AuditLog {
    <#
    .SYNOPSIS
        Records authentication and authorization events
    
    .PARAMETER Action
        Action being audited (Login, Logout, etc.)
    
    .PARAMETER User
        Username performing the action
    
    .PARAMETER Result
        Result of the action (Success, Failed, etc.)
    
    .PARAMETER Details
        Additional details
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        
        [Parameter(Mandatory)]
        [string]$User,
        
        [Parameter(Mandatory)]
        [string]$Result,
        
        [string]$Details = ''
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $computerName = $env:COMPUTERNAME
        
        $logEntry = [PSCustomObject]@{
            Timestamp = $timestamp
            Computer  = $computerName
            User      = $User
            Action    = $Action
            Result    = $Result
            Details   = $Details
        }
        
        # Try to write to centralized log if configured
        if ($Global:Config -and $Global:Config.Security.AuditLogPath) {
            $logPath = Join-Path $Global:Config.Security.AuditLogPath "AuthAudit_$(Get-Date -Format 'yyyyMM').csv"
            
            # Ensure directory exists
            $logDir = Split-Path $logPath -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Append to CSV
            $logEntry | Export-Csv -Path $logPath -Append -NoTypeInformation
        }
        
        # Also write to local event log
        $logName = 'Application'
        $source = 'EMS'
        
        # Create event source if it doesn't exist
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            try {
                [System.Diagnostics.EventLog]::CreateEventSource($source, $logName)
            }
            catch {
                # Silently fail if we don't have permission
            }
        }
        
        if ([System.Diagnostics.EventLog]::SourceExists($source)) {
            $eventType = switch ($Result) {
                'Success' { 'Information' }
                'Failed' { 'FailureAudit' }
                'Unauthorized' { 'Warning' }
                default { 'Information' }
            }
            
            $message = "EMS $Action - User: $User, Result: $Result"
            if ($Details) {
                $message += ", Details: $Details"
            }
            
            Write-EventLog -LogName $logName -Source $source -EventId 1000 -EntryType $eventType -Message $message
        }
        
    }
    catch {
        Write-Warning "Failed to write audit log: $_"
    }
}

Export-ModuleMember -Function Test-ADCredential, Test-UserAuthorization, Write-AuditLog
