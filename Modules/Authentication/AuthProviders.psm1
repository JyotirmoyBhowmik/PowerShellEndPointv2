<#
.SYNOPSIS
    Multi-Provider Authentication Module for EMS
    
.DESCRIPTION
    Supports multiple authentication providers:
    - Standalone: Local database users  
    - Active Directory: Windows AD
    - LDAP: Generic LDAP servers
    - ADFS: Active Directory Federation Services
    - SSO: SAML/OAuth2 providers
    
.NOTES
    Author: Enterprise IT Team
    Version: 2.1
#>

# Import sub-modules
$ModulePath = $PSScriptRoot
Import-Module "$ModulePath\StandaloneAuth.psm1" -Force
Import-Module "$ModulePath\LDAPAuth.psm1" -Force

<#
.SYNOPSIS
    Authenticates user against configured providers
#>
function Invoke-MultiProviderAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [SecureString]$SecurePassword,
        
        [string]$Provider, # Specific provider, or null for fallback chain
        
        [Parameter(Mandatory)]
        [object]$Config
    )
    
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    )
    
    # Get enabled providers sorted by priority
    $enabledProviders = $Config.Authentication.Providers | 
    Where-Object { $_.Enabled -eq $true } |
    Sort-Object Priority
    
    # If specific provider requested
    if ($Provider) {
        $enabledProviders = $enabledProviders | Where-Object { $_.Name -eq $Provider }
        if (-not $enabledProviders) {
            return @{
                Success  = $false
                Message  = "Provider '$Provider' not found or not enabled"
                Provider = $null
                User     = $null
            }
        }
    }
    
    # Try each provider in order
    foreach ($providerConfig in $enabledProviders) {
        try {
            $result = $null
            
            switch ($providerConfig.Name) {
                "Standalone" {
                    $result = Test-StandaloneAuth -Username $Username -Password $plainPassword -Config $Config
                }
                "ActiveDirectory" {
                    $result = Test-ADAuth -Username $Username -SecurePassword $SecurePassword -Domain $providerConfig.Domain
                }
                "LDAP" {
                    $result = Test-LDAPAuth -Username $Username -Password $plainPassword -Config $providerConfig
                }
                "ADFS" {
                    $result = Test-ADFSAuth -Username $Username -Password $plainPassword -Config $providerConfig
                }
                "SSO" {
                    # SSO typically doesn't use username/password, handled differently
                    continue
                }
            }
            
            if ($result -and $result.Success) {
                return @{
                    Success     = $true
                    Provider    = $providerConfig.Name
                    User        = $result.User
                    ExternalID  = $result.ExternalID
                    DisplayName = $result.DisplayName
                    Email       = $result.Email
                    Groups      = $result.Groups
                }
            }
            
        }
        catch {
            Write-EMSLog -Message "Auth provider $($providerConfig.Name) error: $_" -Severity 'Warning'
            
            # If not using fallback chain, return error immediately
            if (-not $Config.Authentication.FallbackChain) {
                return @{
                    Success  = $false
                    Message  = "Authentication failed: $_"
                    Provider = $providerConfig.Name
                }
            }
            # Otherwise continue to next provider
        }
    }
    
    # All providers failed
    return @{
        Success  = $false
        Message  = "Authentication failed for all configured providers"
        Provider = $null
        User     = $null
    }
}

<#
.SYNOPSIS
    Gets or creates user in database after successful authentication
#>
function Get-OrCreateAuthUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AuthResult,
        
        [Parameter(Mandatory)]
        [object]$Config
    )
    
    # Check if user exists in database
    $dbUser = Get-EMSUser -Username $AuthResult.User
    
    if ($dbUser) {
        # Update external ID if changed
        if ($AuthResult.ExternalID -and $dbUser.external_id -ne $AuthResult.ExternalID) {
            $query = "UPDATE users SET external_id = @extid, auth_provider = @provider WHERE user_id = @userid"
            Invoke-PGQuery -Query $query -Parameters @{
                extid    = $AuthResult.ExternalID
                provider = $AuthResult.Provider
                userid   = $dbUser.user_id
            } -NonQuery | Out-Null
        }
        
        # Update last login
        Update-EMSUserLogin -UserId $dbUser.user_id
        
        return $dbUser
    }
    else {
        # Create new user
        $query = @"
INSERT INTO users (username, auth_provider, external_id, display_name, email, role)
VALUES (@username, @provider, @extid, @displayname, @email, @role)
RETURNING user_id
"@
        
        $params = @{
            username    = $AuthResult.User
            provider    = $AuthResult.Provider
            extid       = $AuthResult.ExternalID
            displayname = $AuthResult.DisplayName
            email       = $AuthResult.Email
            role        = 'operator' # Default role
        }
        
        $result = Invoke-PGQuery -Query $query -Parameters $params
        
        # Fetch newly created user
        return Get-EMSUser -UserId $result.user_id
    }
}

<#
.SYNOPSIS
    Tests Active Directory authentication
#>
function Test-ADAuth {
    [CmdletBinding()]
    param(
        [string]$Username,
        [SecureString]$SecurePassword,
        [string]$Domain
    )
    
    try {
        # Use existing AD authentication from Authentication.psm1
        $isValid = Test-ADCredential -Username $Username -SecurePassword $SecurePassword
        
        if ($isValid) {
            # Get AD user details
            $adUser = Get-ADUser -Identity ($Username -replace '.*\\', '') -Properties DisplayName, EmailAddress, MemberOf -ErrorAction SilentlyContinue
            
            return @{
                Success     = $true
                User        = $Username
                ExternalID  = $adUser.ObjectGUID.ToString()
                DisplayName = $adUser.DisplayName
                Email       = $adUser.EmailAddress
                Groups      = $adUser.MemberOf
            }
        }
        
        return @{ Success = $false }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

<#
.SYNOPSIS
    Tests ADFS authentication
#>
function Test-ADFSAuth {
    [CmdletBinding()]
    param(
        [string]$Username,
        [string]$Password,
        [object]$Config
    )
    
    try {
        # ADFS WS-Trust endpoint
        $adfsUrl = "$($Config.ServerURL)/adfs/services/trust/13/usernamemixed"
        
        # Create WS-Trust request
        $soapRequest = @"
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
            xmlns:a="http://www.w3.org/2005/08/addressing"
            xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
  <s:Header>
    <a:Action s:mustUnderstand="1">http://docs.oasis-open.org/ws-sx/ws-trust/200512/RST/Issue</a:Action>
    <a:To s:mustUnderstand="1">$adfsUrl</a:To>
    <o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <o:UsernameToken u:Id="uuid-$([guid]::NewGuid().ToString())">
        <o:Username>$Username</o:Username>
        <o:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">$Password</o:Password>
      </o:UsernameToken>
    </o:Security>
  </s:Header>
  <s:Body>
    <trust:RequestSecurityToken xmlns:trust="http://docs.oasis-open.org/ws-sx/ws-trust/200512">
      <wsp:AppliesTo xmlns:wsp="http://schemas.xmlsoap.org/ws/2004/09/policy">
        <a:EndpointReference>
          <a:Address>$($Config.RelyingPartyIdentifier)</a:Address>
        </a:EndpointReference>
      </wsp:AppliesTo>
      <trust:RequestType>http://docs.oasis-open.org/ws-sx/ws-trust/200512/Issue</trust:RequestType>
    </trust:RequestSecurityToken>
  </s:Body>
</s:Envelope>
"@
        
        $response = Invoke-RestMethod -Uri $adfsUrl -Method POST -Body $soapRequest -ContentType "application/soap+xml"
        
        if ($response) {
            # Parse SAML token for user info
            return @{
                Success     = $true
                User        = $Username
                ExternalID  = $Username # Use claims from token if available
                DisplayName = $Username
                Email       = $null
                Groups      = @()
            }
        }
        
        return @{ Success = $false }
    }
    catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Invoke-MultiProviderAuth',
    'Get-OrCreateAuthUser',
    'Test-ADAuth',
    'Test-ADFSAuth'
)
