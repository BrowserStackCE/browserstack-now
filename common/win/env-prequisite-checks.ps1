# Environment Prerequisite Checks for PowerShell

$script:PROXY_TEST_URL = "https://www.browserstack.com/automate/browsers.json"
$script:PROXY_HOST = ""
$script:PROXY_PORT = ""

function Parse-Proxy {
    param([string]$ProxyUrl)
    # Strip protocol
    $p = $ProxyUrl -replace '^https?://', ''
    # Strip credentials
    $p = $p -replace '^.*@', ''
    
    if ($p -match '^([^:]+):(\d+)$') {
        $script:PROXY_HOST = $matches[1]
        $script:PROXY_PORT = $matches[2]
    }
}

function Set-ProxyInEnv {
    Log-Section "Network & Proxy Validation"
    
    # Detect proxy from env
    $proxy = $env:http_proxy
    if (-not $proxy) { $proxy = $env:HTTP_PROXY }
    if (-not $proxy) { $proxy = $env:https_proxy }
    if (-not $proxy) { $proxy = $env:HTTPS_PROXY }

    if ([string]::IsNullOrWhiteSpace($proxy)) {
        Log-Warn "No proxy found. Using direct connection."
        $script:PROXY_HOST = ""
        $script:PROXY_PORT = ""
        return
    }

    Log-Line "Proxy detected: $proxy" $global:NOW_RUN_LOG_FILE
    Parse-Proxy -ProxyUrl $proxy

    Log-Line "Testing reachability via proxy..." $global:NOW_RUN_LOG_FILE

    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${env:BROWSERSTACK_USERNAME}:${env:BROWSERSTACK_ACCESS_KEY}"))
    
    try {
        $resp = Invoke-WebRequest -Uri $PROXY_TEST_URL -Proxy $proxy -Headers @{ Authorization = "Basic $auth" } -Method Head -ErrorAction Stop
        $statusCode = $resp.StatusCode
        Log-Line "Endpoint reachable. HTTP $statusCode" $global:NOW_RUN_LOG_FILE
        Log-Line "Exporting PROXY_HOST=$script:PROXY_HOST" $global:NOW_RUN_LOG_FILE
        Log-Line "Exporting PROXY_PORT=$script:PROXY_PORT" $global:NOW_RUN_LOG_FILE
        
        $env:PROXY_HOST = $script:PROXY_HOST
        $env:PROXY_PORT = $script:PROXY_PORT
        Log-Success "Connected to BrowserStack from proxy: $script:PROXY_HOST:$script:PROXY_PORT"
    } catch {
        Log-Error "Could not connect to BrowserStack using proxy. Using direct connection."
        Log-Warn "Not reachable ($($_.Exception.Message)). Clearing variables." $global:NOW_RUN_LOG_FILE
        $script:PROXY_HOST = ""
        $script:PROXY_PORT = ""
        $env:PROXY_HOST = ""
        $env:PROXY_PORT = ""
    }
}

function Check-Java-Installation {
    Log-Line "Checking if 'java' command exists..." $global:NOW_RUN_LOG_FILE
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        Log-Error "Java command not found in PATH." $global:NOW_RUN_LOG_FILE
        return $false
    }

    Log-Line "Checking if Java runs correctly..." $global:NOW_RUN_LOG_FILE
    try {
        $output = java -version 2>&1 | Out-String
        Log-Success "Java installed and functional`n$output"
        return $true
    } catch {
        Log-Error "Java exists but failed to run." $global:NOW_RUN_LOG_FILE
        return $false
    }
}

function Check-Python-Installation {
    Log-Line "Checking if 'python' command exists..." $global:NOW_RUN_LOG_FILE
    # Windows usually uses 'python', not 'python3'
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pyCmd) { 
        $pyCmd = Get-Command python3 -ErrorAction SilentlyContinue 
    }
    
    if (-not $pyCmd) {
        Log-Error "Python command not found in PATH." $global:NOW_RUN_LOG_FILE
        return $false
    }

    Log-Line "Checking if Python runs correctly..." $global:NOW_RUN_LOG_FILE
    try {
        $output = & $pyCmd.Name --version 2>&1 | Out-String
        Log-Success "Python default installation: $output"
        return $true
    } catch {
        Log-Error "Python exists but failed to run." $global:NOW_RUN_LOG_FILE
        return $false
    }
}

function Check-NodeJS-Installation {
    Log-Line "Checking if 'node' command exists..." $global:NOW_RUN_LOG_FILE
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Log-Error "Node.js command not found in PATH." $global:NOW_RUN_LOG_FILE
        return $false
    }

    Log-Line "Checking if 'npm' command exists..." $global:NOW_RUN_LOG_FILE
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Log-Error "npm command not found in PATH." $global:NOW_RUN_LOG_FILE
        return $false
    }

    Log-Line "Checking if Node.js runs correctly..." $global:NOW_RUN_LOG_FILE
    try {
        $nodeVer = node -v 2>&1 | Out-String
        $npmVer = npm -v 2>&1 | Out-String
        Log-Success "Node.js installed: $nodeVer"
        Log-Success "npm installed: $npmVer"
        return $true
    } catch {
        Log-Error "Node.js/npm exists but failed to run." $global:NOW_RUN_LOG_FILE
        return $false
    }
}

function Validate-Tech-Stack {
    param([string]$TechStack)
    
    Log-Section "System Prerequisites Check"
    Log-Info "Checking prerequisites for $TechStack"

    $valid = $false
    switch ($TechStack.ToLower()) {
        "java" { $valid = Check-Java-Installation }
        "python" { $valid = Check-Python-Installation }
        "nodejs" { $valid = Check-NodeJS-Installation }
        default {
            Log-Error "Unknown tech stack selected: $TechStack" $global:NOW_RUN_LOG_FILE
            return $false
        }
    }

    if ($valid) {
        Log-Line "Prerequisites validated for $TechStack" $global:NOW_RUN_LOG_FILE
        return $true
    } else {
        return $false
    }
}
