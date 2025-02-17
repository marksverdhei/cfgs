# Configs and scripts for CS2  

Attribution: some code is imported from [](https://github.com/gucu112/cs2-config/)

Quickstart:  

## Snapshot configuration (TODO)  
Not implemented but planning to add a script that writes current game state to cfgs  

## Sync config to logged in user  

This script adds all configs to game data and imports video settings for given user.  
Requirements: powershell (with admin rights), python3  

```powershell
. .\scripts\sync_cfg_video.ps1
```

## Video config  
Configure video settings in `video_settings`. Make your own json file or use one of the default configs.    
TODO: make game name mapping