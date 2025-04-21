#!/bin/bash

# Default values
default_video_config="video_settings/1440p.json"
# Common Steam paths on Linux
possible_steam_paths=(
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
)
default_cs2_app_id="730" # CS2 App ID

# --- Function Definitions ---

# Function to print verbose messages (mimics Write-Verbose somewhat)
# Usage: log_verbose "My message"
log_verbose() {
    if [[ "$verbose" = true ]]; then
        echo "VERBOSE: $1"
    fi
}

# Function to print error messages and exit
# Usage: die "Error message"
die() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- Parameter Handling ---

# Assign parameters - simple positional assignment like the PowerShell script
video_config_arg="$1"
steam_base_path_arg="$2"
steam_user_id_arg="$3"
echo $steam_base_path_arg
echo $steam_base_path

echo $steam_user_id_arg
# --- Determine Script Path ---
# $PSScriptRoot equivalent

base_path="."
echo "Script base path: $base_path"

# --- Determine Steam Base Path ---
steam_base_path=""
if [[ -n "$steam_base_path_arg" ]]; then
    # Use provided path if it exists
    if [[ -d "$steam_base_path_arg" ]]; then
        steam_base_path="$steam_base_path_arg"
        log_verbose "Using provided Steam base path: $steam_base_path"
    else
        die "Provided Steam base path does not exist: $steam_base_path_arg"
    fi
else
    # Attempt to find default Steam path
    for path_attempt in "${possible_steam_paths[@]}"; do
        if [[ -d "$path_attempt" ]]; then
            steam_base_path="$path_attempt"
            echo "Steam base path not provided, using found path: $steam_base_path"
            break
        fi
    done
    if [[ -z "$steam_base_path" ]]; then
        die "Could not find Steam base path automatically. Please provide it as the second argument."
    fi
fi

# --- Determine Steam User ID ---
# --- Start Replacement: Auto-detect Steam User ID using find ---
log_verbose "Attempting to auto-detect Steam user ID using find..."
valid_user_dirs=() # Initialize empty array
steam_userdata_path="$steam_base_path/userdata"
echo "Steam base path: $steam_userdata_path"
# Check if the userdata path actually exists
if [[ ! -d "$steam_userdata_path" ]]; then
    die "Steam userdata directory not found: $steam_userdata_path"
fi

# Use find to locate directories directly under userdata whose names are purely numeric
# -mindepth 1 -maxdepth 1: Only look directly inside userdata, not deeper
# -type d: Find items that are directories
# -regextype posix-extended -regex '.*/[0-9]+$': Use regex to match paths ending in /<digits>
# If find fails, it will produce no output, mapfile will be empty
mapfile -t found_paths < <(find "$steam_userdata_path" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended -regex '.*/[0-9]+$' 2>/dev/null)

# Extract just the directory name (the ID) from the full paths found
if [[ ${#found_paths[@]} -gt 0 ]]; then
     log_verbose "Found potential user ID directories using find:"
     for dir_path in "${found_paths[@]}"; do
         # Ensure the found path is actually a directory before using basename
         if [[ -d "$dir_path" ]]; then
            user_id=$(basename "$dir_path")
            log_verbose " - Path: $dir_path, Extracted ID: $user_id"
            # Add the extracted numeric ID to our list
            valid_user_dirs+=("$user_id")
         else
             log_verbose " - Warning: find returned '$dir_path', but it's not a directory. Skipping."
         fi
     done
else
     log_verbose "find command did not locate any numeric directories in '$steam_userdata_path'"
fi

steam_user_id="$steam_user_id_arg"

if [[ -z "$steam_user_id_arg" ]]; then
    # Check how many valid user IDs were found and assigned
    if [[ ${#valid_user_dirs[@]} -eq 1 ]]; then
        steam_user_id="${valid_user_dirs[0]}"
        echo "Steam User ID not provided, automatically found single user ID: $steam_user_id"
    elif [[ ${#valid_user_dirs[@]} -gt 1 ]]; then
        echo "ERROR: Multiple potential Steam user IDs found in $steam_userdata_path:" >&2
        printf " - %s\n" "${valid_user_dirs[@]}" >&2
        die "Please specify the correct Steam User ID as the third argument."
    else
        # This error message now clearly relates to the find method
        die "Could not automatically find any valid numeric Steam User ID directory in '$steam_userdata_path'. Please provide the ID as the third argument."
    fi
fi
# --- End Replacement Block ---

# --- Determine Video Config Path ---
video_config="$video_config_arg"
if [[ -z "$video_config" ]]; then
    video_config="$default_video_config"
    echo "Video config not provided, attempting default relative path: $video_config"
fi

# Resolve the video config path relative to the script's location
video_config_full_path="$base_path/$video_config"
if [[ ! -f "$video_config_full_path" ]]; then
    die "Video config file not found: $video_config_full_path"
fi
log_verbose "Using video config file: $video_config_full_path"

# --- Determine CS2 Installation Path ---
# This is trickier than registry on Windows. We'll *assume* it's in the default library
# A more robust solution would parse libraryfolders.vdf
cs2_install_name="Counter-Strike Global Offensive" # Still uses the old name in the path
game_base_path="$steam_base_path/steamapps/common/$cs2_install_name"

if [[ ! -d "$game_base_path" ]]; then
    # Add logic here to search other libraries if needed by parsing:
    # "$steam_base_path/steamapps/libraryfolders.vdf"
    die "Could not find CS2 installation path at the default location: $game_base_path. (Parsing other libraries not implemented yet)."
fi
log_verbose "Found CS2 base path: $game_base_path"

# --- Construct Configuration Paths ---
# Note: CS2 structure on Linux matches Windows mostly
game_config_path="$game_base_path/game/csgo/cfg"
legacy_config_path="$game_base_path/csgo/cfg" # Kept for parity with PS script, usefulness in CS2 Linux TBD
user_settings_path="$steam_userdata_path/$steam_user_id/$default_cs2_app_id/local/cfg"
video_settings_path="$user_settings_path/cs2_video.txt"

# Create user settings directory if it doesn't exist (Steam usually does this)
mkdir -p "$user_settings_path" || die "Failed to create user settings directory: $user_settings_path"

# --- Log Paths ---
log_verbose "CS2 Game Config Path: $game_config_path"
log_verbose "CS2 Legacy Config Path: $legacy_config_path"
log_verbose "Steam User Settings Path: $user_settings_path"
log_verbose "CS2 Video Settings Path: $video_settings_path"

# --- Copy Configuration Files ---
source_cfg_dir="$base_path/cfgs"
if [[ ! -d "$source_cfg_dir" ]]; then
    die "Source configuration directory not found: $source_cfg_dir"
fi

log_verbose "Performing the operation 'Update CS2 Config' on target '$game_config_path'"

# Enable nullglob to prevent errors if no *.cfg files are found
shopt -s nullglob

cfg_files=("$source_cfg_dir"/*.cfg)
if [[ ${#cfg_files[@]} -gt 0 ]]; then
    echo "Copying *.cfg files from $source_cfg_dir to $game_config_path..."
    cp -fv "${cfg_files[@]}" "$game_config_path/" || die "Failed to copy configs to $game_config_path"

    # Also copy to legacy path (matching PowerShell script)
    if [[ -d "$legacy_config_path" ]]; then
         echo "Copying *.cfg files from $source_cfg_dir to $legacy_config_path..."
        cp -fv "${cfg_files[@]}" "$legacy_config_path/" || die "Failed to copy configs to $legacy_config_path"
    else
        echo "Skipping copy to legacy path (does not exist): $legacy_config_path"
    fi
else
    echo "No *.cfg files found in $source_cfg_dir to copy."
fi

# Disable nullglob
shopt -u nullglob

# --- Export Environment Variables ---
# Note: 'export' makes these available to subprocesses (like the python script)
# but they are *not* persistent like the PowerShell User EnvironmentVariableTarget.
export CURRENT_USER="$steam_user_id"
export USER_SETTINGS_PATH="$user_settings_path"

echo "Environment variables set for this session:"
echo "CURRENT_USER = $CURRENT_USER"
echo "USER_SETTINGS_PATH = $USER_SETTINGS_PATH"

# --- Run Python Script ---
python_script_path="$base_path/scripts/overwrite_video_config.py"
if [[ ! -f "$python_script_path" ]]; then
    die "Python script not found: $python_script_path"
fi

echo "Running Python script to update video settings..."
# Use python3 explicitly if it's the standard on the system
python3 "$python_script_path" "$video_config_full_path" "$video_settings_path"

if [[ $? -eq 0 ]]; then
    echo "Python script completed successfully."
else
    die "Python script failed."
fi

echo "CS2 configuration update process finished."
exit 0