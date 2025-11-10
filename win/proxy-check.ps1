#requires -version 5.0
<#
  BrowserStack Proxy Detection and Validation
  - Detects proxy from environment variables
  - Tests BrowserStack API connectivity through proxy
  - Exports PROXY_HOST and PROXY_PORT if successful
#>

param(
    [string]$BrowserStackUsername,
    [string]$BrowserStackAccessKey
)

$ErrorActionPreference = 'Continue'

# Test URL for connectivity check
$TEST_URL = "https://www.browserstack.com/automate/browsers.json"

# Function to parse proxy URL
function Parse-ProxyUrl {
    param([string]$ProxyUrl)
    
    if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
        return $null
    }
    
    # Remove protocol (http:// or https://)
    $cleaned = $ProxyUrl -replace '^https?://', ''
    
    # Remove credentials if present (user:pass@)
    if ($cleaned -match '@') {
        $cleaned = $cleaned.Substring($cleaned.IndexOf('@') + 1)
    }
    
    # Extract host and port
    if ($cleaned -match '^([^:]+):(\d+)') {
        return @{
            Host = $matches[1]
            Port = $matches[2]
        }
    } elseif ($cleaned -match '^([^:]+)') {
        # No port specified, use default
        return @{
            Host = $matches[1]
            Port = "8080"  # default proxy port
        }
    }
    
    return $null
}

# Detect proxy from environment variables (case-insensitive)
$PROXY = $env:http_proxy
if ([string]::IsNullOrWhiteSpace($PROXY)) { $PROXY = $env:HTTP_PROXY }
if ([string]::IsNullOrWhiteSpace($PROXY)) { $PROXY = $env:https_proxy }
if ([string]::IsNullOrWhiteSpace($PROXY)) { $PROXY = $env:HTTPS_PROXY }

# Reset output variables
$env:PROXY_HOST = ""
$env:PROXY_PORT = ""

# If no proxy configured, exit early
if ([string]::IsNullOrWhiteSpace($PROXY)) {
    Write-Host "No proxy found in environment. Clearing proxy host and port variables."
    $env:PROXY_HOST = ""
    $env:PROXY_PORT = ""
    exit 0
}

Write-Host "Proxy detected: $PROXY"

# Parse proxy URL
$proxyInfo = Parse-ProxyUrl -ProxyUrl $PROXY
if (-not $proxyInfo) {
    Write-Host "❌ Failed to parse proxy URL: $PROXY"
    $env:PROXY_HOST = ""
    $env:PROXY_PORT = ""
    exit 1
}

Write-Host "Testing reachability via proxy..."
Write-Host "  Proxy Host: $($proxyInfo.Host)"
Write-Host "  Proxy Port: $($proxyInfo.Port)"

# Encode BrowserStack credentials in Base64
$base64Creds = ""
if (-not [string]::IsNullOrWhiteSpace($BrowserStackUsername) -and 
    -not [string]::IsNullOrWhiteSpace($BrowserStackAccessKey)) {
    $pair = "${BrowserStackUsername}:${BrowserStackAccessKey}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
    $base64Creds = [System.Convert]::ToBase64String($bytes)
}

# Test connectivity through proxy
try {
    $proxyUri = "http://$($proxyInfo.Host):$($proxyInfo.Port)"
    
    # Create web request with proxy
    $webProxy = New-Object System.Net.WebProxy($proxyUri)
    $webClient = New-Object System.Net.WebClient
    $webClient.Proxy = $webProxy
    
    # Add authorization header if credentials provided
    if (-not [string]::IsNullOrWhiteSpace($base64Creds)) {
        $webClient.Headers.Add("Authorization", "Basic $base64Creds")
    }
    
    # Attempt to download (with timeout)
    $null = $webClient.DownloadString($TEST_URL)
    
    # If we reach here, the request succeeded
    Write-Host "✅ Reachable. HTTP 200"
    Write-Host "Exporting PROXY_HOST=$($proxyInfo.Host)"
    Write-Host "Exporting PROXY_PORT=$($proxyInfo.Port)"
    
    $env:PROXY_HOST = $proxyInfo.Host
    $env:PROXY_PORT = $proxyInfo.Port
    
    exit 0
    
} catch {
    $statusCode = "Unknown"
    if ($_.Exception.InnerException -and $_.Exception.InnerException.Response) {
        $statusCode = [int]$_.Exception.InnerException.Response.StatusCode
    }
    
    Write-Host "❌ Not reachable (HTTP $statusCode). Clearing variables."
    Write-Host "   Error: $($_.Exception.Message)"
    
    $env:PROXY_HOST = ""
    $env:PROXY_PORT = ""
    
    exit 0  # Exit successfully even if proxy check fails
}

