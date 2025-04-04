param (
    [string]$VideoConfig,
    [string]$SteamBasePath,
    [string]$SteamCurrentUser
)

$BasePath = $PSScriptRoot

# Get steam ID if not provided
if (-not $SteamCurrentUser) {
    $SteamCurrentUser = Get-ItemPropertyValue -Path 'HKCU:\Software\Valve\Steam\ActiveProcess' -Name 'ActiveUser'
}

if (-not $SteamBasePath) {
    $SteamBasePath = 'C:\Program Files (x86)\Steam'
    Write-Host "Steam base path not provided, attempting default path: $SteamBasePath"
}

if (-not $VideoConfig) {
    $VideoConfig = 'video_settings/1440p.json'
    Write-Host "Video config not provided, attempting default path: $VideoConfig"
}

$GameBasePath = Get-ItemPropertyValue -Path 'HKLM:\Software\WOW6432Node\Valve\CS2' -Name 'InstallPath'
$GameConfigPath = Join-Path $GameBasePath 'game\csgo\cfg'
$LegacyConfigPath = Join-Path $GameBasePath 'csgo\cfg'

$UserSettingsPath = Join-Path $SteamBasePath 'userdata' 
$UserSettingsPath = Join-Path $UserSettingsPath $SteamCurrentUser
$UserSettingsPath = Join-Path $UserSettingsPath '730\local\cfg'
$VideoSettingsPath = Join-Path $UserSettingsPath 'cs2_video.txt'
# Get game configuration directory
Write-Verbose $GameBasePath -Verbose
Write-Verbose $GameConfigPath -Verbose
Write-Verbose $SteamBasePath -Verbose
Write-Verbose $UserSettingsPath -Verbose

Write-Verbose "Performing the operation `"Update CS2 Config`" on target `"Item: $GameConfigPath`"." -Verbose

Get-ChildItem -Path "cfgs\" -Filter "*.cfg" | Copy-Item -Destination $GameConfigPath -Recurse -Force -Verbose
# If using CSGO (note, you may need to change the config as csgo and cs2 use different commands)
Get-ChildItem -Path "cfgs\" -Filter "*.cfg" | Copy-Item -Destination $LegacyConfigPath -Recurse -Force -Verbose

# Export environment variables
[System.Environment]::SetEnvironmentVariable('CURRENT_USER', $SteamCurrentUser, [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('USER_SETTINGS_PATH', $UserSettingsPath, [System.EnvironmentVariableTarget]::User)

Write-Host "Environment variables set:"
Write-Host "CURRENT_USER = $SteamCurrentUser"
Write-Host "USER_SETTINGS_PATH = $UserSettingsPath"

python .\scripts\overwrite_video_config.py $VideoConfig $VideoSettingsPath