$script:CONFIG_FILE = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\config\devices.txt"

function Get-Matching-Devices {
    param([string]$PlatformName)
    
    $devices = @()
    if (-not (Test-Path $script:CONFIG_FILE)) { return $devices }
    
    $lines = Get-Content $script:CONFIG_FILE
    
    if ($PlatformName -eq "android" -or $PlatformName -eq "ios") {
        foreach ($line in $lines) {
            if ($line -match "^MOBILE\|") {
                $entry = $line -replace "^MOBILE\|", ""
                $prefix = ($entry -split '\|')[0]
                if ($prefix -eq $PlatformName) {
                    $devices += $entry
                }
            }
        }
    } else {
        # Web includes WEB and MOBILE
        foreach ($line in $lines) {
            if ($line -match "^WEB\|") {
                $devices += ($line -replace "^WEB\|", "")
            } elseif ($line -match "^MOBILE\|") {
                $devices += ($line -replace "^MOBILE\|", "")
            }
        }
    }
    return $devices
}

function Pick-Terminal-Devices {
    param(
        [string]$PlatformName,
        [string]$Count,
        [string]$PlatformsListContentFormat
    )

    $Count = $Count -replace ',$', ''
    if (-not ($Count -match '^\d+$')) { return "" }

    $matchingDevices = Get-Matching-Devices -PlatformName $PlatformName
    if ($matchingDevices.Count -eq 0) { return "" }

    $yaml = ""
    $jsonList = @()
    $countInt = [int]$Count

    for ($i = 1; $i -le $countInt; $i++) {
        $index = ($i - 1) % $matchingDevices.Count
        $entry = $matchingDevices[$index]
        $parts = $entry -split '\|'
        $prefixEntry = $parts[0]
        $suffixEntry = $parts[1]
        
        $mod = $i % 4
        $hardcodedBVersion = 140
        $bVersionLiteral = ""
        if (($i % 4) -ne 0) { $bVersionLiteral = "-$mod" }
        $bVersion = "latest$bVersionLiteral"

        if ($PlatformsListContentFormat -eq "yaml") {
            if ($prefixEntry -eq "android" -or $prefixEntry -eq "ios") {
                $yaml += "  - platformName: $prefixEntry`n    deviceName: $suffixEntry`n"
            } else {
                $browserVer = $hardcodedBVersion - $i
                $yaml += "  - osVersion: $prefixEntry`n    browserName: $suffixEntry`n    browserVersion: $browserVer`n"
            }
            if ($i -lt $countInt) { $yaml += "`n" }
        } elseif ($PlatformsListContentFormat -eq "json") {
            if ($prefixEntry -eq "android" -or $prefixEntry -eq "ios") {
                $obj = @{ platformName = $prefixEntry; "bstack:options" = @{ deviceName = $suffixEntry } }
                $jsonList += $obj
            } else {
                $obj = @{ "bstack:options" = @{ os = $prefixEntry }; browserName = $suffixEntry; browserVersion = $bVersion }
                $jsonList += $obj
            }
        }
    }

    if ($PlatformsListContentFormat -eq "yaml") {
        return $yaml
    } else {
        return ($jsonList | ConvertTo-Json -Depth 5 -Compress)
    }
}