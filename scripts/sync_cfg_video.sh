#!/bin/bash
set -e  # exit on error

# Function to display usage
usage() {
  echo "Usage: $0 [-v VideoConfig] [-s SteamBasePath] [-u SteamCurrentUser]"
  exit 1
}

# Default values
VideoConfig=""
SteamBasePath=""
SteamCurrentUser=""

# Parse command-line options
while getopts "v:s:u:" opt; do
  case ${opt} in
    v)
      VideoConfig="$OPTARG"
      ;;
    s)
      SteamBasePath="$OPTARG"
      ;;
    u)
      SteamCurrentUser="$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

# Base path: directory where this script is located
BasePath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get SteamCurrentUser from registry if not provided
if [ -z "$SteamCurrentUser" ]; then
  echo "SteamCurrentUser not provided, attempting to retrieve from registry..."
  # Query registry and extract the ActiveUser value.
  SteamCurrentUser=$(reg query "HKCU\\Software\\Valve\\Steam\\ActiveProcess" /v ActiveUser 2>/dev/null | grep "ActiveUser" | awk '{print $3}')
fi

# Set default SteamBasePath if not provided
if [ -z "$SteamBasePath" ]; then
  SteamBasePath="C:\\Program Files (x86)\\Steam"
  echo "Steam base path not provided, attempting default path: $SteamBasePath"
fi

# Set default VideoConfig if not provided
if [ -z "$VideoConfig" ]; then
  VideoConfig="video_settings/1440p.json"
  echo "Video config not provided, attempting default path: $VideoConfig"
fi

# Get GameBasePath from registry
GameBasePath=$(reg query "HKLM\\Software\\WOW6432Node\\Valve\\CS2" /v InstallPath 2>/dev/null | grep "InstallPath" | awk '{print $3}')
if [ -z "$GameBasePath" ]; then
  echo "Failed to retrieve GameBasePath from registry."
  exit 1
fi

# Build GameConfigPath by appending "game/csgo/cfg"
GameConfigPath="${GameBasePath}\\game\\csgo\\cfg"

# Build UserSettingsPath: SteamBasePath/userdata/SteamCurrentUser/730/local/cfg
UserSettingsPath="${SteamBasePath}\\userdata\\${SteamCurrentUser}\\730\\local\\cfg"

# Define VideoSettingsPath as a file within the UserSettingsPath
VideoSettingsPath="${UserSettingsPath}\\cs2_video.txt"

# Verbose logging of paths
echo "GameBasePath: $GameBasePath"
echo "GameConfigPath: $GameConfigPath"
echo "SteamBasePath: $SteamBasePath"
echo "UserSettingsPath: $UserSettingsPath"

echo "Performing the operation \"Update CS2 Config\" on target \"Item: $GameConfigPath\"."

# Copy all .cfg files from the "cfgs" directory (relative to the script location)
SRC_CFGS="${BasePath}/cfgs"
if [ ! -d "$SRC_CFGS" ]; then
  echo "Source cfgs directory not found: $SRC_CFGS"
  exit 1
fi

# Copying files (adjusting for Windows paths if necessary)
echo "Copying .cfg files from ${SRC_CFGS} to ${GameConfigPath}"
# Using cp -r; if on Windows you might need to adjust or use a different copy method.
cp -r "$SRC_CFGS"/*.cfg "$(cygpath -u "$GameConfigPath")"

# Export environment variables for the current session
export CURRENT_USER="$SteamCurrentUser"
export USER_SETTINGS_PATH="$UserSettingsPath"

echo "Environment variables set:"
echo "CURRENT_USER = $CURRENT_USER"
echo "USER_SETTINGS_PATH = $USER_SETTINGS_PATH"

# Execute the Python script to overwrite video configuration
python ./scripts/overwrite_video_config.py "$VideoConfig" "$VideoSettingsPath"
