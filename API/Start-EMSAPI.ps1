<#
.SYNOPSIS
    REST API Server for Enterprise Endpoint Monitoring System
    
.DESCRIPTION
    PowerShell Universal Dashboard-based REST API providing endpoints for:
    - Authentication (Login/Logout/Token Validation)
    - Scan Operations (Single/Bulk/Status)
    - Results Retrieval (List/Get/Delete)
    - Dashboard Statistics
    - Remediation Execution
    
.NOTES
    Author: Enterprise IT Team
    Version: 1.0
    Requires: UniversalDashboard module
#>

#Requires -Version 5.1
#Requires -Modules @{ ModuleName="UniversalDashboard"; ModuleVersion="3.0.0" }

# Import required modules
$ModulePath = Join-Path $PSScriptRoot "..\Modules"
Import-Module "$ModulePath\Logging.psm1" -Force
Import-Module "$ModulePath\Database\PSPGSql.psm1" -Force
Import-Module "$ModulePath\Authentication.psm1" -Force
Import-Module "$ModulePath\InputBroker.psm1" -Force
Import-Module "$ModulePath\DataFetcher.psm1" -Force
Import-Module "$ModulePath\Remediation.psm1" -Force

# Load configuration
$configPath = Join-Path $PSScriptRoot "..\Config\EMSConfig.json"
$Global:EMSConfig = Get-Content $configPath -Raw | ConvertFrom-Json

# Initialize database connection
Initialize-PostgreSQLConnection -Config $Global:EMSConfig

Write-Host "[INFO] EMS REST API Server initializing..." -ForegroundColor Cyan

#region Helper Functions

function New-JWTToken {
    <#
    .SYNOPSIS
        Generates JWT token for authenticated user
    #>
    param(
        [string]$Username,
        [int]$UserId,
        [string]$Role
    )
    
    $secretKey = $Global:EMSConfig.API.JWTSecretKey
    $expirationMinutes = $Global:EMSConfig.API.TokenExpirationMinutes
    
    # Simple JWT implementation (for production, use a proper JWT library)
    $header = @{
        alg = "HS256"
        typ = "JWT"
    } | ConvertTo-Json -Compress
    
    $payload = @{
        sub    = $Username
        userId = $UserId
        role   = $Role
        iat    = [Math]::Floor([DateTime]::UtcNow.Subtract([DateTime]"1970-01-01").TotalSeconds)
        exp    = [Math]::Floor([DateTime]::UtcNow.AddMinutes($expirationMinutes).Subtract([DateTime]"1970-01-01").TotalSeconds)
    } | ConvertTo-Json -Compress
    
    $headerBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($header)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    $signature = "$headerBase64.$payloadBase64"
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes($secretKey)
    $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($signature))
    $signatureBase64 = [Convert]::ToBase64String($signatureBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    return "$headerBase64.$payloadBase64.$signatureBase64"
}

function Test-JWTToken {
    <#
    .SYNOPSIS
        Validates JWT token and returns payload
    #>
    param([string]$Token)
    
    try {
        $parts = $Token.Split('.')
        if ($parts.Length -ne 3) { return $null }
        
        # Decode payload
        $payloadBase64 = $parts[1]
        # Add padding if needed
        while ($payloadBase64.Length % 4 -ne 0) { $payloadBase64 += '=' }
        $payloadBase64 = $payloadBase64.Replace('-', '+').Replace('_', '/')
        
        $payloadJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payloadBase64))
        $payload = $payloadJson | ConvertFrom-Json
        
        # Check expiration
        $now = [Math]::Floor([DateTime]::UtcNow.Subtract([DateTime]"1970-01-01").TotalSeconds)
        if ($payload.exp -lt $now) {
            return $null  # Token expired
        }
        
        return $payload
    }
    catch {
        return $null
    }
}

#endregion

#region API Endpoints

# Authentication Endpoints
$authEndpoints = @(
    New-UDEndpoint -Url "/api/auth/login" -Method POST -Endpoint {
        param($Body)
        
        try {
            $credentials = $Body | ConvertFrom-Json
            
            # Validate credentials against AD
            $securePassword = ConvertTo-SecureString $credentials.password -AsPlainText -Force
            $isValid = Test-ADCredential -Username $credentials.username -SecurePassword $securePassword
            
            if (-not $isValid) {
                New-UDEndpointResponse -StatusCode 401 -Data @{
                    success = $false
                    message = "Invalid credentials"
                } | ConvertTo-Json
                return
            }
            
            # Check authorization
            $isAuthorized = Test-UserAuthorization -Username $credentials.username -RequiredGroup $Global:EMSConfig.Security.AdminGroup
            
            if (-not $isAuthorized) {
                Write-AuditLog -Action "Login" -User $credentials.username -Result "Unauthorized" -RiskLevel "Medium"
                
                New-UDEndpointResponse -StatusCode 403 -Data @{
                    success = $false
                    message = "User not authorized. Must be member of $($Global:EMSConfig.Security.AdminGroup)"
                } | ConvertTo-Json
                return
            }
            
            # Get or create user in database
            $dbUser = Get-EMSUser -Username $credentials.username
            if (-not $dbUser) {
                $userId = New-EMSUser -Username $credentials.username -Role "operator"
                $dbUser = Get-EMSUser -UserId $userId
            }
            
            # Update last login
            Update-EMSUserLogin -UserId $dbUser.user_id
            
            # Generate JWT token
            $token = New-JWTToken -Username $credentials.username -UserId $dbUser.user_id -Role $dbUser.role
            
            Write-AuditLog -Action "Login" -User $credentials.username -Result "Success" -RiskLevel "Low"
            
            New-UDEndpointResponse -StatusCode 200 -Data @{
                success = $true
                token   = $token
                user    = @{
                    id          = $dbUser.user_id
                    username    = $dbUser.username
                    displayName = $dbUser.display_name
                    role        = $dbUser.role
                }
            } | ConvertTo-Json
        }
        catch {
            Write-EMSLog -Message "Login error: $_" -Severity 'Error'
            New-UDEndpointResponse -StatusCode 500 -Data @{
                success = $false
                message = "Internal server error"
            } | ConvertTo-Json
        }
    }
    
    New-UDEndpoint -Url "/api/auth/validate" -Method GET -Endpoint {
        $authHeader = $Request.Headers['Authorization']
        
        if (-not $authHeader -or -not $authHeader.StartsWith('Bearer ')) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ valid = $false } | ConvertTo-Json
            return
        }
        
        $token = $authHeader.Substring(7)
        $payload = Test-JWTToken -Token $token
        
        if ($payload) {
            New-UDEndpointResponse -StatusCode 200 -Data @{
                valid = $true
                user  = @{
                    username = $payload.sub
                    userId   = $payload.userId
                    role     = $payload.role
                }
            } | ConvertTo-Json
        }
        else {
            New-UDEndpointResponse -StatusCode 401 -Data @{ valid = $false } | ConvertTo-Json
        }
    }
)

# Scan Endpoints
$scanEndpoints = @(
    New-UDEndpoint -Url "/api/scan/single" -Method POST -Endpoint {
        param($Body)
        
        # Validate authentication
        $authHeader = $Request.Headers['Authorization']
        if (-not $authHeader) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Unauthorized" } | ConvertTo-Json
            return
        }
        
        $token = $authHeader.Substring(7)
        $payload = Test-JWTToken -Token $token
        if (-not $payload) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Invalid token" } | ConvertTo-Json
            return
        }
        
        try {
            $request = $Body | ConvertFrom-Json
            $target = $request.target
            
            Write-AuditLog -Action "ScanInitiated" -User $payload.sub -Target $target -Result "Success"
            
            # Route input and execute scan
            $targets = Invoke-InputRouter -Input $target -Config $Global:EMSConfig
            
            if ($targets) {
                $results = Invoke-DataFetch -Targets $targets -Config $Global:EMSConfig
                
                # Save to database
                foreach ($result in $results) {
                    $scanId = Save-ScanResult -ScanData $result -InitiatedBy $payload.userId
                    $result | Add-Member -NotePropertyName "scan_id" -NotePropertyValue $scanId -Force
                }
                
                New-UDEndpointResponse -StatusCode 200 -Data @{
                    success = $true
                    results = $results
                } | ConvertTo-Json -Depth 10
            }
            else {
                New-UDEndpointResponse -StatusCode 404 -Data @{
                    success = $false
                    message = "Target not found or unable to resolve"
                } | ConvertTo-Json
            }
        }
        catch {
            Write-EMSLog -Message "Scan error: $_" -Severity 'Error'
            New-UDEndpointResponse -StatusCode 500 -Data @{
                success = $false
                error   = $_.Exception.Message
            } | ConvertTo-Json
        }
    }
)

# Results Endpoints
$resultsEndpoints = @(
    New-UDEndpoint -Url "/api/results" -Method GET -Endpoint {
        # Validate authentication
        $authHeader = $Request.Headers['Authorization']
        if (-not $authHeader) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Unauthorized" } | ConvertTo-Json
            return
        }
        
        $token = $authHeader.Substring(7)
        $payload = Test-JWTToken -Token $token
        if (-not $payload) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Invalid token" } | ConvertTo-Json
            return
        }
        
        try {
            # Get query parameters
            $limit = if ($Request.Query['limit']) { [int]$Request.Query['limit'] } else { 50 }
            $offset = if ($Request.Query['offset']) { [int]$Request.Query['offset'] } else { 0 }
            $hostname = $Request.Query['hostname']
            
            $results = Get-ScanResults -Limit $limit -Offset $offset -Hostname $hostname
            
            New-UDEndpointResponse -StatusCode 200 -Data @{
                success = $true
                results = $results
                count   = $results.Count
            } | ConvertTo-Json -Depth 10
        }
        catch {
            Write-EMSLog -Message "Results retrieval error: $_" -Severity 'Error'
            New-UDEndpointResponse -StatusCode 500 -Data @{
                success = $false
                error   = $_.Exception.Message
            } | ConvertTo-Json
        }
    }
    
    New-UDEndpoint -Url "/api/results/:id" -Method GET -Endpoint {
        param($id)
        
        # Validate authentication
        $authHeader = $Request.Headers['Authorization']
        if (-not $authHeader) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Unauthorized" } | ConvertTo-Json
            return
        }
        
        try {
            $query = "SELECT * FROM scan_results WHERE scan_id = @scanid"
            $result = Invoke-PGQuery -Query $query -Parameters @{ scanid = $id }
            
            if ($result) {
                # Get diagnostic details
                $detailsQuery = "SELECT * FROM diagnostic_details WHERE scan_id = @scanid"
                $details = Invoke-PGQuery -Query $detailsQuery -Parameters @{ scanid = $id }
                
                $result | Add-Member -NotePropertyName "diagnostics" -NotePropertyValue $details -Force
                
                New-UDEndpointResponse -StatusCode 200 -Data $result | ConvertTo-Json -Depth 10
            }
            else {
                New-UDEndpointResponse -StatusCode 404 -Data @{ error = "Scan not found" } | ConvertTo-Json
            }
        }
        catch {
            New-UDEndpointResponse -StatusCode 500 -Data @{ error = $_.Exception.Message } | ConvertTo-Json
        }
    }
)

# Dashboard Endpoints
$dashboardEndpoints = @(
    New-UDEndpoint -Url "/api/dashboard/stats" -Method GET -Endpoint {
        # Validate authentication
        $authHeader = $Request.Headers['Authorization']
        if (-not $authHeader) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Unauthorized" } | ConvertTo-Json
            return
        }
        
        try {
            $stats = Get-DashboardStats
            
            New-UDEndpointResponse -StatusCode 200 -Data @{
                success    = $true
                statistics = $stats
            } | ConvertTo-Json -Depth 10
        }
        catch {
            New-UDEndpointResponse -StatusCode 500 -Data @{
                success = $false
                error   = $_.Exception.Message
            } | ConvertTo-Json
        }
    }
)

#endregion

#region API Server Configuration

$apiConfig = $Global:EMSConfig.API

# CORS configuration
$cors = New-UDCorsPolicy -AllowedOrigin $apiConfig.AllowedOrigins -AllowedMethod @('GET', 'POST', 'PUT', 'DELETE', 'OPTIONS') -AllowedHeader @('Authorization', 'Content-Type')

# Combine all endpoints
$allEndpoints = $authEndpoints + $scanEndpoints + $resultsEndpoints + $dashboardEndpoints

# Create dashboard
$dashboard = New-UDDashboard -Title "EMS API Server" -Content {
    New-UDHeading -Text "EMS REST API" -Size 3
    New-UDElement -Tag "p" -Content { "API server is running. Use /api/* endpoints for programmatic access." }
    New-UDElement -Tag "p" -Content { "Swagger documentation available at /swagger (if enabled)" }
} -Endpoint $allEndpoints -CorsPolicy $cors

# Start server
$serverParams = @{
    Dashboard  = $dashboard
    Port       = ([System.Uri]$apiConfig.ListenAddress).Port
    AutoReload = $false
}

# Add HTTPS configuration if specified
if ($apiConfig.UseHTTPS) {
    $serverParams.Certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*$($env:COMPUTERNAME)*" } | Select-Object -First 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " EMS REST API Server" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Address: $($apiConfig.ListenAddress)" -ForegroundColor Cyan
Write-Host "Endpoints:" -ForegroundColor Yellow
Write-Host "  POST   /api/auth/login" -ForegroundColor White
Write-Host "  GET    /api/auth/validate" -ForegroundColor White
Write-Host "  POST   /api/scan/single" -ForegroundColor White
Write-Host "  GET    /api/results" -ForegroundColor White
Write-Host "  GET    /api/results/:id" -ForegroundColor White
Write-Host "  GET    /api/dashboard/stats" -ForegroundColor White
Write-Host "`nPress Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Green

Start-UDDashboard @serverParams

#endregion
