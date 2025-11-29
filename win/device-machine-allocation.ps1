$WEB_ALL = @(
  "Windows|Chrome"
  "Windows|Firefox"
  "Windows|Edge"
  "Windows|Chrome"
  "Windows|Chrome"
  "OS X|Chrome"
  "OS X|Safari"
  "OS X|Chrome"
  "OS X|Safari"
  "OS X|Firefox"
  "OS X|Safari"
    # Tier 1
  "ios|iPhone 1[234567]*"
  "android|Samsung Galaxy S*"

  # Tier 2
  "ios|iPad Air*"
  "android|Samsung Galaxy Tab*"
  "android|Samsung Galaxy M*"
  "android|Google Pixel [56789]*"
  "android|Vivo Y*"
  "android|Oppo*"

  # Tier 4
  "ios|iPhone SE*"
  "ios|iPad Pro*"
  "android|Samsung Galaxy A*"
  "android|Google Pixel 10*"
  "android|OnePlus *"
  "android|Vivo V*"
  "android|Xiaomi *"
  "android|Huawei *"
)


# MOBILE_ALL combines the tiers
$MOBILE_ALL = @(
    # Tier 1
  "ios|iPhone 1[234567]*"
  "android|Samsung Galaxy S*"

  # Tier 2
  "ios|iPad Air*"
  "android|Samsung Galaxy Tab*"
  "android|Samsung Galaxy M*"
  "android|Google Pixel [56789]*"
  "android|Vivo Y*"
  "android|Oppo*"

  # Tier 4
  "ios|iPad Pro*"
  "android|Samsung Galaxy A*"
  "android|Google Pixel 10*"
  "android|OnePlus *"
  "android|Vivo V*"
  "android|Xiaomi *"
  "android|Huawei *"
)

function Generate-Platforms {
    param(
        [string]$platformName,
        [string]$count,
        [string]$platformsListContentFormat
    )

    # Remove trailing comma
    $count = $count.TrimEnd(',')

    # Validate input
    if ([string]::IsNullOrWhiteSpace($platformName) -or
        [string]::IsNullOrWhiteSpace($count)) {

        log_msg_to "Platform name for parallel count is invalid: $platformName $count"
        return 1
    }

    # Validate numeric count
    if (-not ($count -match '^[0-9]+$')) {
        log_msg_to "Error: count must be a number."
        return 1
    }

    $count = [int]$count

    # ------------------------------------
    # Build matching device list
    # ------------------------------------
    $matching_devices = @()

    if ($platformName -eq "android" -or $platformName -eq "ios") {
        foreach ($entry in $MOBILE_ALL) {
            $prefix = $entry.Split('|')[0]
            if ($prefix -eq $platformName) {
                $matching_devices += $entry
            }
        }
    } else {
        foreach ($entry in $WEB_ALL) {
            $matching_devices += $entry
        }
    }

    # ------------------------------------
    # Loop count times
    # ------------------------------------
    $yaml = ""
    $jsonEntries = @()

    $hardcodedBVersion = 140

    for ($i = 1; $i -le $count; $i++) {

        $index = ($i - 1) % $matching_devices.Count

        $entry        = $matching_devices[$index]
        $prefixEntry  = $entry.Split('|')[0]
        $suffixEntry  = $entry.Split('|')[1]

        # browserVersion rotating pattern
        $mod = $i % 4
        if ($mod -ne 0) {
            $bVersion = "latest-$mod"
        } else {
            $bVersion = "latest"
        }

        # -------- YAML MODE --------
        if ($platformsListContentFormat -eq "yaml") {

            if ($prefixEntry -eq "android" -or $prefixEntry -eq "ios") {
                $yaml += "  - platformName: $prefixEntry`n"
                $yaml += "    deviceName: $suffixEntry`n"
            }
            else {
                $browserVersionCalc = $hardcodedBVersion - $i
                $yaml += "  - osVersion: $prefixEntry`n"
                $yaml += "    browserName: $suffixEntry`n"
                $yaml += "    browserVersion: $browserVersionCalc`n"
            }

            if ($i -lt $count) {
                $yaml += "`n"
            }

        }
        # -------- JSON MODE --------
        elseif ($platformsListContentFormat -eq "json") {

            if ($prefixEntry -eq "android" -or $prefixEntry -eq "ios") {

                $jsonEntries += @{
                    platformName   = $prefixEntry
                    "bstack:options" = @{
                        deviceName = $suffixEntry
                    }
                }

            } else {

                $jsonEntries += @{
                    "bstack:options" = @{ os = $prefixEntry }
                    browserName      = $suffixEntry
                    browserVersion   = $bVersion
                }
            }
        }
    }

    # Output final result
    if ($platformsListContentFormat -eq "yaml") {
        Write-Output $yaml
    }
    else {
        # Convert PowerShell objects → compact JSON
        $json = ($jsonEntries | ConvertTo-Json -Depth 5)
        Write-Output $json
    }
}