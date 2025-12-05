# Device and platform allocation utilities for the Windows BrowserStack NOW flow.
# Mirrors the macOS shell script structure so we can share logic between both platforms.

# ===== Example Platform Templates =====
$WEB_PLATFORM_TEMPLATES = @(
  "Windows|10|Chrome",
  "Windows|10|Firefox",
  "Windows|11|Edge",
  "Windows|11|Chrome",
  "Windows|8|Chrome",
  "OS X|Monterey|Chrome",
  "OS X|Ventura|Chrome",
  "OS X|Catalina|Firefox"
)

# Mobile tiers (kept for parity)
$MOBILE_TIER1 = @(
  "ios|iPhone 15|17",
  "ios|iPhone 15 Pro|17",
  "ios|iPhone 16|18",
  "android|Samsung Galaxy S25|15",
  "android|Samsung Galaxy S24|14"
)
$MOBILE_TIER2 = @(
  "ios|iPhone 14 Pro|16",
  "ios|iPhone 14|16",
  "ios|iPad Air 13 2025|18",
  "android|Samsung Galaxy S23|13",
  "android|Samsung Galaxy S22|12",
  "android|Samsung Galaxy S21|11",
  "android|Samsung Galaxy Tab S10 Plus|15"
)
$MOBILE_TIER3 = @(
  "ios|iPhone 13 Pro Max|15",
  "ios|iPhone 13|15",
  "ios|iPhone 12 Pro|14",
  "ios|iPhone 12 Pro|17",
  "ios|iPhone 12|17",
  "ios|iPhone 12|14",
  "ios|iPhone 12 Pro Max|16",
  "ios|iPhone 13 Pro|15",
  "ios|iPhone 13 Mini|15",
  "ios|iPhone 16 Pro|18",
  "ios|iPad 9th|15",
  "ios|iPad Pro 12.9 2020|14",
  "ios|iPad Pro 12.9 2020|16",
  "ios|iPad 8th|16",
  "android|Samsung Galaxy S22 Ultra|12",
  "android|Samsung Galaxy S21|12",
  "android|Samsung Galaxy S21 Ultra|11",
  "android|Samsung Galaxy S20|10",
  "android|Samsung Galaxy M32|11",
  "android|Samsung Galaxy Note 20|10",
  "android|Samsung Galaxy S10|9",
  "android|Samsung Galaxy Note 9|8",
  "android|Samsung Galaxy Tab S8|12",
  "android|Google Pixel 9|15",
  "android|Google Pixel 6 Pro|13",
  "android|Google Pixel 8|14",
  "android|Google Pixel 7|13",
  "android|Google Pixel 6|12",
  "android|Vivo Y21|11",
  "android|Vivo Y50|10",
  "android|Oppo Reno 6|11"
)
$MOBILE_TIER4 = @(
  "ios|iPhone 15 Pro Max|17",
  "ios|iPhone 15 Pro Max|26",
  "ios|iPhone 15|26",
  "ios|iPhone 15 Plus|17",
  "ios|iPhone 14 Pro|26",
  "ios|iPhone 14|18",
  "ios|iPhone 14|26",
  "ios|iPhone 13 Pro Max|18",
  "ios|iPhone 13|16",
  "ios|iPhone 13|17",
  "ios|iPhone 13|18",
  "ios|iPhone 12 Pro|18",
  "ios|iPhone 14 Pro Max|16",
  "ios|iPhone 14 Plus|16",
  "ios|iPhone 11|13",
  "ios|iPhone 8|11",
  "ios|iPhone 7|10",
  "ios|iPhone 17 Pro Max|26",
  "ios|iPhone 17 Pro|26",
  "ios|iPhone 17 Air|26",
  "ios|iPhone 17|26",
  "ios|iPhone 16e|18",
  "ios|iPhone 16 Pro Max|18",
  "ios|iPhone 16 Plus|18",
  "ios|iPhone SE 2020|16",
  "ios|iPhone SE 2022|15",
  "ios|iPad Air 4|14",
  "ios|iPad 9th|18",
  "ios|iPad Air 5|26",
  "ios|iPad Pro 11 2021|18",
  "ios|iPad Pro 13 2024|17",
  "ios|iPad Pro 12.9 2021|14",
  "ios|iPad Pro 12.9 2021|17",
  "ios|iPad Pro 11 2024|17",
  "ios|iPad Air 6|17",
  "ios|iPad Pro 12.9 2022|16",
  "ios|iPad Pro 11 2022|16",
  "ios|iPad 10th|16",
  "ios|iPad Air 13 2025|26",
  "ios|iPad Pro 11 2020|13",
  "ios|iPad Pro 11 2020|16",
  "ios|iPad 8th|14",
  "ios|iPad Mini 2021|15",
  "ios|iPad Pro 12.9 2018|12",
  "ios|iPad 6th|11",
  "android|Samsung Galaxy S23 Ultra|13",
  "android|Samsung Galaxy S22 Plus|12",
  "android|Samsung Galaxy S21 Plus|11",
  "android|Samsung Galaxy S20 Ultra|10",
  "android|Samsung Galaxy S25 Ultra|15",
  "android|Samsung Galaxy S24 Ultra|14",
  "android|Samsung Galaxy M52|11",
  "android|Samsung Galaxy A52|11",
  "android|Samsung Galaxy A51|10",
  "android|Samsung Galaxy A11|10",
  "android|Samsung Galaxy A10|9",
  "android|Samsung Galaxy Tab A9 Plus|14",
  "android|Samsung Galaxy Tab S9|13",
  "android|Samsung Galaxy Tab S7|10",
  "android|Samsung Galaxy Tab S7|11",
  "android|Samsung Galaxy Tab S6|9",
  "android|Google Pixel 9|16",
  "android|Google Pixel 10 Pro XL|16",
  "android|Google Pixel 10 Pro|16",
  "android|Google Pixel 10|16",
  "android|Google Pixel 9 Pro XL|15",
  "android|Google Pixel 9 Pro|15",
  "android|Google Pixel 6 Pro|12",
  "android|Google Pixel 6 Pro|15",
  "android|Google Pixel 8 Pro|14",
  "android|Google Pixel 7 Pro|13",
  "android|Google Pixel 5|11",
  "android|OnePlus 13R|15",
  "android|OnePlus 12R|14",
  "android|OnePlus 11R|13",
  "android|OnePlus 9|11",
  "android|OnePlus 8|10",
  "android|Motorola Moto G71 5G|11",
  "android|Motorola Moto G9 Play|10",
  "android|Vivo V21|11",
  "android|Oppo A96|11",
  "android|Oppo Reno 3 Pro|10",
  "android|Xiaomi Redmi Note 11|11",
  "android|Xiaomi Redmi Note 9|10",
  "android|Huawei P30|9"
)

# MOBILE_ALL combines the tiers
$MOBILE_ALL = @()
$MOBILE_ALL += $MOBILE_TIER1
$MOBILE_ALL += $MOBILE_TIER2
$MOBILE_ALL += $MOBILE_TIER3
$MOBILE_ALL += $MOBILE_TIER4

# ===== Generators =====
function Generate-Web-Platforms-Yaml {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 0) { $max = 0 }
  $sb = New-Object System.Text.StringBuilder
  $count = 0

  foreach ($t in $WEB_PLATFORM_TEMPLATES) {
    $parts = $t.Split('|')
    $os = $parts[0]; $osVersion = $parts[1]; $browserName = $parts[2]
    foreach ($version in @('latest','latest-1','latest-2')) {
      [void]$sb.AppendLine("  - os: $os")
      [void]$sb.AppendLine("    osVersion: $osVersion")
      [void]$sb.AppendLine("    browserName: $browserName")
      [void]$sb.AppendLine("    browserVersion: $version")
      $count++
      if ($count -ge $max -and $max -gt 0) {
        return $sb.ToString()
      }
    }
  }
  return $sb.ToString()
}

function Generate-Mobile-Platforms-Yaml {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 1) { $max = 1 }
  $sb = New-Object System.Text.StringBuilder
  $count = 0

  foreach ($t in $MOBILE_ALL) {
    $parts = $t.Split('|')
    $platformName  = $parts[0]
    $deviceName    = $parts[1]
    $platformVer   = $parts[2]

    if (-not [string]::IsNullOrWhiteSpace($APP_PLATFORM)) {
      if ($APP_PLATFORM -eq 'ios' -and $platformName -ne 'ios') { continue }
      if ($APP_PLATFORM -eq 'android' -and $platformName -ne 'android') { continue }
    }

    [void]$sb.AppendLine("  - platformName: $platformName")
    [void]$sb.AppendLine("    deviceName: $deviceName")
    [void]$sb.AppendLine("    platformVersion: '${platformVer}.0'")
    $count++
    if ($count -ge $max) { return $sb.ToString() }
  }
  return $sb.ToString()
}

function Generate-Mobile-Caps-Json {
  param([int]$MaxTotalParallels, [string]$OutputFile)
  $json = Generate-Mobile-Caps-Json-String -MaxTotalParallels $MaxTotalParallels
  Set-ContentNoBom -Path $OutputFile -Value $json
  return $json
}

function Generate-Mobile-Caps-Json-String {
  param([int]$MaxTotalParallels)
  $max = $MaxTotalParallels
  if ($max -lt 1) { $max = 1 }

  $items = @()
  $count = 0

  foreach ($t in $MOBILE_ALL) {
    $parts = $t.Split('|')
    $platformName = $parts[0]
    $deviceName   = $parts[1]
    $platformVer  = $parts[2]

    # Filter based on APP_PLATFORM
    if (-not [string]::IsNullOrWhiteSpace($APP_PLATFORM)) {
      if ($APP_PLATFORM -eq 'ios' -and $platformName -ne 'ios') { continue }
      if ($APP_PLATFORM -eq 'android' -and $platformName -ne 'android') { continue }
    }

    $items += [pscustomobject]@{
      'bstack:options' = @{
        deviceName = $deviceName
        osVersion  = "${platformVer}.0"
      }
    }
    $count++
    if ($count -ge $max) { break }
  }

  $json = ($items | ConvertTo-Json -Depth 5 -Compress)
  return $json
}

function Generate-Web-Caps-Json {
  param([int]$MaxTotalParallels)
  $max = [Math]::Floor($MaxTotalParallels * $PARALLEL_PERCENTAGE)
  if ($max -lt 1) { $max = 1 }

  $items = @()
  $count = 0
  foreach ($t in $WEB_PLATFORM_TEMPLATES) {
    $parts = $t.Split('|')
    $os = $parts[0]; $osVersion = $parts[1]; $browserName = $parts[2]
    foreach ($version in @('latest','latest-1','latest-2')) {
      $items += [pscustomobject]@{
        browserName    = $browserName
        browserVersion = $version
        'bstack:options' = @{
          os        = $os
          osVersion = $osVersion
        }
      }
      $count++
      if ($count -ge $max) { break }
    }
    if ($count -ge $max) { break }
  }

  # Return valid JSON array (keep the brackets!)
  $json = ($items | ConvertTo-Json -Depth 5 -Compress)
  return $json
}



