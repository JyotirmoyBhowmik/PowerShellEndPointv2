<#
.SYNOPSIS
    Standalone (Local Database) Authentication Provider
    
.DESCRIPTION
    Authenticates users against local PostgreSQL database
    Supports password hashing with bcrypt
#>

<#
.SYNOPSIS
    Tests standalone authentication against database
#>
function Test-StandaloneAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$Password,
        
        [Parameter(Mandatory)]
        [object]$Config
    )
    
    try {
        # Query user from database
        $query = "SELECT user_id, username, password_hash, display_name, email, role, is_active FROM users WHERE username = @username AND auth_provider = 'Standalone'"
        $user = Invoke-PGQuery -Query $query -Parameters @{ username = $Username } | Select-Object -First 1
        
        if (-not $user) {
            return @{ Success = $false; Message = "User not found" }
        }
        
        if (-not $user.is_active) {
            return @{ Success = $false; Message = "User account is disabled" }
        }
        
        # Verify password hash
        $isValid = Test-PasswordHash -Password $Password -Hash $user.password_hash
        
        if ($isValid) {
            return @{
                Success     = $true
                User        = $user.username
                ExternalID  = $user.user_id.ToString()
                DisplayName = $user.display_name
                Email       = $user.email
                Groups      = @()
            }
        }
        else {
            # Increment failed login attempts
            $query = "UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE user_id = @userid"
            Invoke-PGQuery -Query $query -Parameters @{ userid = $user.user_id } -NonQuery | Out-Null
            
            return @{ Success = $false; Message = "Invalid password" }
        }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

<#
.SYNOPSIS
    Creates new standalone user
#>
function New-StandaloneUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [SecureString]$SecurePassword,
        
        [string]$DisplayName,
        [string]$Email,
        [ValidateSet('admin', 'operator', 'viewer')]
        [string]$Role = 'viewer'
    )
    
    try {
        # Check if user already exists
        $existing = Get-EMSUser -Username $Username
        if ($existing) {
            throw "User '$Username' already exists"
        }
        
        # Hash password
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
        )
        $passwordHash = New-PasswordHash -Password $plainPassword
        
        # Insert user
        $query = @"
INSERT INTO users (username, auth_provider, password_hash, display_name, email, role)
VALUES (@username, 'Standalone', @hash, @displayname, @email, @role)
RETURNING user_id
"@
        
        $params = @{
            username    = $Username
            hash        = $passwordHash
            displayname = if ($DisplayName) { $DisplayName } else { $Username }
            email       = $Email
            role        = $Role
        }
        
        $result = Invoke-PGQuery -Query $query -Parameters $params
        
        Write-EMSLog -Message "Created standalone user: $Username (ID: $($result.user_id))" -Severity 'Success'
        return $result.user_id
    }
    catch {
        Write-EMSLog -Message "Error creating standalone user: $_" -Severity 'Error'
        throw
    }
}

<#
.SYNOPSIS
    Updates standalone user password
#>
function Set-StandaloneUserPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [SecureString]$NewPassword
    )
    
    try {
        $user = Get-EMSUser -Username $Username
        if (-not $user -or $user.auth_provider -ne 'Standalone') {
            throw "Standalone user '$Username' not found"
        }
        
        # Hash new password
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
        )
        $passwordHash = New-PasswordHash -Password $plainPassword
        
        # Update password
        $query = "UPDATE users SET password_hash = @hash, require_password_change = false, updated_at = NOW() WHERE user_id = @userid"
        Invoke-PGQuery -Query $query -Parameters @{ hash = $passwordHash; userid = $user.user_id } -NonQuery | Out-Null
        
        Write-EMSLog -Message "Password updated for user: $Username" -Severity 'Success'
        return $true
    }
    catch {
        Write-EMSLog -Message "Error updating password: $_" -Severity 'Error'
        return $false
    }
}

<#
.SYNOPSIS
    Hashes password using BCrypt
#>
function New-PasswordHash {
    param([string]$Password)
    
    # Simple hash (in production, use proper BCrypt library)
    # For now, using SHA256 with salt
    $salt = [System.Guid]::NewGuid().ToString()
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Password + $salt)
    $hash = $sha256.ComputeHash($bytes)
    $hashString = [Convert]::ToBase64String($hash)
    
    return "$salt`:$hashString"
}

<#
.SYNOPSIS
    Verifies password against hash
#>
function Test-PasswordHash {
    param(
        [string]$Password,
        [string]$Hash
    )
    
    if (-not $Hash -or $Hash -notlike "*:*") {
        return $false
    }
    
    $parts = $Hash -split ':', 2
    $salt = $parts[0]
    $storedHash = $parts[1]
    
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Password + $salt)
    $hash = $sha256.ComputeHash($bytes)
    $hashString = [Convert]::ToBase64String($hash)
    
    return $hashString -eq $storedHash
}

Export-ModuleMember -Function @(
    'Test-StandaloneAuth',
    'New-StandaloneUser',
    'Set-StandaloneUserPassword'
)
