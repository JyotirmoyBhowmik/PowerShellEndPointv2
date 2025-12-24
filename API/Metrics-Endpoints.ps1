# Generic Metrics API Endpoint Generator
# Add to Start-EMSAPI.ps1 after computer endpoints

$metricsEndpoints = @(
    # Generic metric query endpoint
    New-UDEndpoint -Url "/api/metrics/:metricType" -Method GET -Endpoint {
        param($metricType)
        
        $authHeader = $Request.Headers['Authorization']
        if (-not $authHeader) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Unauthorized" } | ConvertTo-Json
            return
        }
        
        try {
            # Parse query params
            $computerName = $Request.Query['computerName']
            $startDate = $Request.Query['startDate']
            $endDate = $Request.Query['endDate']
            $limit = if ($Request.Query['limit']) { [int]$Request.Query['limit'] } else { 100 }
            
            # Build SQL based on metric type
            $tableName = "metric_$($metricType -replace '-','_')"
            
            $whereClause = @()
            $params = @{}
            
            if ($computerName) {
                $whereClause += "computer_name ILIKE @computer"
                $params.computer = "%$computerName%"
            }
            
            if ($startDate) {
                $where Clause += "timestamp >= @start"
                $params.start = $startDate
            }
            
            if ($endDate) {
                $whereClause += "timestamp <= @end"
                $params.end = $endDate
            }
            
            $whereSql = if ($whereClause.Count -gt 0) { "WHERE " + ($whereClause -join " AND ") } else { "" }
            
            $query = "SELECT * FROM $tableName $whereSql ORDER BY timestamp DESC LIMIT @limit"
            $params.limit = $limit
            
            $results = Invoke-PGQuery -Query $query -Parameters $params
            
            New-UDEndpointResponse -StatusCode 200 -Data @{
                success = $true
                data    = $results
                count   = $results.Count
            } | ConvertTo-Json -Depth 10
        }
        catch {
            New-UDEndpointResponse -StatusCode 500 -Data @{ 
                success = $false
                error   = $_.Exception.Message 
            } | ConvertTo-Json
        }
    }
    
    # Computer-specific all metrics
    New-UDEndpoint -Url "/api/computers/:name/all-metrics" -Method GET -Endpoint {
        param($name)
        
        $authHeader = $Request.Headers['Authorization']
        if (-not $authHeader) {
            New-UDEndpointResponse -StatusCode 401 -Data @{ error = "Unauthorized" } | ConvertTo-Json
            return
        }
        
        try {
            # Get all metric types for a computer
            $metrics = @{
                computer_name       = $name
                cpu                 = Invoke-PGQuery -Query "SELECT * FROM metric_cpu_usage WHERE computer_name = @name ORDER BY timestamp DESC LIMIT 1" -Parameters @{ name = $name }
                memory              = Invoke-PGQuery -Query "SELECT * FROM metric_memory WHERE computer_name = @name ORDER BY timestamp DESC LIMIT 1" -Parameters @{ name = $name }
                disks               = Invoke-PGQuery -Query "SELECT * FROM metric_disk_space WHERE computer_name = @name AND timestamp > NOW() - INTERVAL '1 day'" -Parameters @{ name = $name }
                windows_updates     = Invoke-PGQuery -Query "SELECT * FROM metric_windows_updates WHERE computer_name = @name ORDER BY timestamp DESC LIMIT 1" -Parameters @{ name = $name }
                antivirus           = Invoke-PGQuery -Query "SELECT * FROM metric_antivirus WHERE computer_name = @name ORDER BY timestamp DESC LIMIT 1" -Parameters @{ name = $name }
                firewall            = Invoke-PGQuery -Query "SELECT * FROM metric_firewall WHERE computer_name = @name ORDER BY timestamp DESC LIMIT 1" -Parameters @{ name = $name }
                network_connections = Invoke-PGQuery -Query "SELECT * FROM metric_network_connections WHERE computer_name = @name AND timestamp > NOW() - INTERVAL '1 hour' LIMIT 20" -Parameters @{ name = $name }
                installed_software  = Invoke-PGQuery -Query "SELECT software_name, version, vendor FROM metric_installed_software WHERE computer_name = @name AND timestamp > NOW() - INTERVAL '7 days' ORDER BY software_name LIMIT 100" -Parameters @{ name = $name }
            }
            
            New-UDEndpointResponse -StatusCode 200 -Data $metrics | ConvertTo-Json -Depth 10
        }
        catch {
            New-UDEndpointResponse -StatusCode 500 -Data @{ error = $_.Exception.Message } | ConvertTo-Json
        }
    }
)

# Add to $allEndpoints
$allEndpoints = $authEndpoints + $scanEndpoints + $resultsEndpoints + $computerEndpoints + $metricsEndpoints + $dashboardEndpoints

# Add to endpoint listing output
Write-Host "  GET    /api/metrics/:metricType" -ForegroundColor White
Write-Host "  GET    /api/computers/:name/all-metrics" -ForegroundColor White
