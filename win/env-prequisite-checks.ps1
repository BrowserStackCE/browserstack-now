# ==============================================
# 🧩 ENVIRONMENT PREREQUISITE CHECKS
# ==============================================

function Validate-Tech-Stack {
  Log-Line "ℹ️ Checking prerequisites for $script:TECH_STACK" $GLOBAL_LOG
  switch ($script:TECH_STACK) {
    "Java" {
      Log-Line "🔍 Checking if 'java' command exists..." $GLOBAL_LOG
      if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        Log-Line "❌ Java command not found in PATH." $GLOBAL_LOG
        throw "Java not found"
      }
      Log-Line "🔍 Checking if Java runs correctly..." $GLOBAL_LOG
      $verInfo = & cmd /c 'java -version 2>&1'
      if (-not $verInfo) {
        Log-Line "❌ Java exists but failed to run." $GLOBAL_LOG
        throw "Java invocation failed"
      }
      Log-Line "✅ Java is installed. Version details:" $GLOBAL_LOG
      ($verInfo -split "`r?`n") | ForEach-Object { if ($_ -ne "") { Log-Line "  $_" $GLOBAL_LOG } }
    }
    "Python" {
      Log-Line "🔍 Checking if 'python3' command exists..." $GLOBAL_LOG
      try {
        Set-PythonCmd
        Log-Line "🔍 Checking if Python3 runs correctly..." $GLOBAL_LOG
        $code = Invoke-Py -Arguments @("--version") -LogFile $null -WorkingDirectory (Get-Location).Path
        if ($code -eq 0) {
          Log-Line ("✅ Python3 is installed: {0}" -f ( ($PY_CMD -join ' ') )) $GLOBAL_LOG
        } else {
          throw "Python present but failed to execute"
        }
      } catch {
        Log-Line "❌ Python3 exists but failed to run." $GLOBAL_LOG
        throw
      }
    }

    "NodeJS" {
      Log-Line "🔍 Checking if 'node' command exists..." $GLOBAL_LOG
      if (-not (Get-Command node -ErrorAction SilentlyContinue)) { 
        Log-Line "❌ Node.js command not found in PATH." $GLOBAL_LOG
        throw "Node not found" 
      }
      Log-Line "🔍 Checking if 'npm' command exists..." $GLOBAL_LOG
      if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { 
        Log-Line "❌ npm command not found in PATH." $GLOBAL_LOG
        throw "npm not found" 
      }
      Log-Line "🔍 Checking if Node.js runs correctly..." $GLOBAL_LOG
      $nodeVer = & node -v 2>&1
      if (-not $nodeVer) {
        Log-Line "❌ Node.js exists but failed to run." $GLOBAL_LOG
        throw "Node.js invocation failed"
      }
      Log-Line "🔍 Checking if npm runs correctly..." $GLOBAL_LOG
      $npmVer = & npm -v 2>&1
      if (-not $npmVer) {
        Log-Line "❌ npm exists but failed to run." $GLOBAL_LOG
        throw "npm invocation failed"
      }
      Log-Line "✅ Node.js is installed: $nodeVer" $GLOBAL_LOG
      Log-Line "✅ npm is installed: $npmVer" $GLOBAL_LOG
    }
    default { Log-Line "❌ Unknown tech stack selected: $script:TECH_STACK" $GLOBAL_LOG; throw "Unknown tech stack" }
  }
  Log-Line "✅ Prerequisites validated for $script:TECH_STACK" $GLOBAL_LOG
}

# fix Python branch without ternary
function Get-PythonCmd {
  if (Get-Command python3 -ErrorAction SilentlyContinue) { return "python3" }
  return "python"
}
