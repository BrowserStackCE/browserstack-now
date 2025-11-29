# Environment prerequisite checks (proxy + tech stack validation).

$PROXY_TEST_URL = "https://www.browserstack.com/automate/browsers.json"

function Parse-ProxyUrl {
  param([string]$ProxyUrl)
  if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    return $null
  }

  $cleaned = $ProxyUrl -replace '^https?://', ''
  if ($cleaned -match '@') {
    $cleaned = $cleaned.Substring($cleaned.IndexOf('@') + 1)
  }

  if ($cleaned -match '^([^:]+):(\d+)') {
    return @{
      Host = $matches[1]
      Port = $matches[2]
    }
  } elseif ($cleaned -match '^([^:]+)') {
    return @{
      Host = $matches[1]
      Port = "8080"
    }
  }
  return $null
}

function Set-ProxyInEnv {
  param(
    [string]$Username,
    [string]$AccessKey
  )

  Log-Section "🌐 Network & Proxy Validation" $NOW_RUN_LOG_FILE
  Log-Line "Checking proxy in environment" $NOW_RUN_LOG_FILE
  $proxy = $env:http_proxy
  if ([string]::IsNullOrWhiteSpace($proxy)) { $proxy = $env:HTTP_PROXY }
  if ([string]::IsNullOrWhiteSpace($proxy)) { $proxy = $env:https_proxy }
  if ([string]::IsNullOrWhiteSpace($proxy)) { $proxy = $env:HTTPS_PROXY }

  $env:PROXY_HOST = ""
  $env:PROXY_PORT = ""

  if ([string]::IsNullOrWhiteSpace($proxy)) {
    Log-Line "No proxy found in environment. Using direct connection." $NOW_RUN_LOG_FILE
    return
  }

  Log-Line "Proxy detected: $proxy" $NOW_RUN_LOG_FILE
  $proxyInfo = Parse-ProxyUrl -ProxyUrl $proxy
  if (-not $proxyInfo) {
    Log-Line "❌ Failed to parse proxy URL: $proxy" $NOW_RUN_LOG_FILE
    return
  }

  $pair = if ($Username -and $AccessKey) { "$Username`:$AccessKey" } else { "" }
  $base64Creds = ""
  if ($pair) {
    $base64Creds = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
  }

  try {
    $proxyUri = "http://$($proxyInfo.Host):$($proxyInfo.Port)"
    $webProxy = New-Object System.Net.WebProxy($proxyUri)
    $webClient = New-Object System.Net.WebClient
    $webClient.Proxy = $webProxy
    if ($base64Creds) {
      $webClient.Headers.Add("Authorization", "Basic $base64Creds")
    }

    $null = $webClient.DownloadString($PROXY_TEST_URL)

    Log-Line "✅ Reachable via proxy. HTTP 200" $NOW_RUN_LOG_FILE
    Log-Line "Exporting PROXY_HOST=$($proxyInfo.Host)" $NOW_RUN_LOG_FILE
    Log-Line "Exporting PROXY_PORT=$($proxyInfo.Port)" $NOW_RUN_LOG_FILE
    $env:PROXY_HOST = $proxyInfo.Host
    $env:PROXY_PORT = $proxyInfo.Port
  } catch {
    $statusMsg = $_.Exception.Message
    Log-Line "❌ Not reachable via proxy. Error: $statusMsg" $NOW_RUN_LOG_FILE
    $env:PROXY_HOST = ""
    $env:PROXY_PORT = ""
  }
}

function Validate-Tech-Stack {
  Log-Line "ℹ️ Checking prerequisites for $script:TECH_STACK" $NOW_RUN_LOG_FILE
  switch ($script:TECH_STACK) {
    "Java" {
      if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        Log-Line "❌ Java command not found in PATH." $NOW_RUN_LOG_FILE
        throw "Java not found"
      }
      $verInfo = & cmd /c 'java -version 2>&1'
      if (-not $verInfo) {
        Log-Line "❌ Java exists but failed to run." $NOW_RUN_LOG_FILE
        throw "Java invocation failed"
      }
      Log-Line "✅ Java is installed. Version details:" $NOW_RUN_LOG_FILE
      ($verInfo -split "`r?`n") | ForEach-Object { if ($_ -ne "") { Log-Line "  $_" $NOW_RUN_LOG_FILE } }
    }
    "Python" {
      try {
        Set-PythonCmd
        $code = Invoke-Py -Arguments @("--version") -LogFile $null -WorkingDirectory (Get-Location).Path
        if ($code -eq 0) {
          Log-Line ("✅ Python3 is installed: {0}" -f ( ($PY_CMD -join ' ') )) $NOW_RUN_LOG_FILE
        } else {
          throw "Python present but failed to execute"
        }
      } catch {
        Log-Line "❌ Python3 exists but failed to run." $NOW_RUN_LOG_FILE
        throw
      }
    }
    "NodeJS" {
      if (-not (Get-Command node -ErrorAction SilentlyContinue)) { 
        Log-Line "❌ Node.js command not found in PATH." $NOW_RUN_LOG_FILE
        throw "Node not found" 
      }
      if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { 
        Log-Line "❌ npm command not found in PATH." $NOW_RUN_LOG_FILE
        throw "npm not found" 
      }
      $nodeVer = & node -v 2>&1
      if (-not $nodeVer) {
        Log-Line "❌ Node.js exists but failed to run." $NOW_RUN_LOG_FILE
        throw "Node.js invocation failed"
      }
      $npmVer = & npm -v 2>&1
      if (-not $npmVer) {
        Log-Line "❌ npm exists but failed to run." $NOW_RUN_LOG_FILE
        throw "npm invocation failed"
      }
      Log-Line "✅ Node.js is installed: $nodeVer" $NOW_RUN_LOG_FILE
      Log-Line "✅ npm is installed: $npmVer" $NOW_RUN_LOG_FILE
    }
    default {
      Log-Line "❌ Unknown TECH_STACK: $script:TECH_STACK" $NOW_RUN_LOG_FILE
      throw "Unknown tech stack"
    }
  }
}



