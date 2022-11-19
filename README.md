# SteamRoller
Automatic Configurator for the SteamDeck

## What does SteamRoller do?

* Set the password for the `deck` user (local user used in desktop mode)
* Put the root filesystem into Read/Write mode (it is typically in ReadOnly mode)
* Increase the size of the swap file (the default is 1GB, but more is better especially when more ram is dedicated to the GPU)
* Decrease kernel Swappiness (to prioritize ram over swap)
* Enable FSTrim timer, and set to weekly (by default SteamOS doesn't do any trimming, so over time the drive starts slowing down)
* Run initial FSTrim (it hasnt been run before)
* Configure `pacman` with arch repos
* Refresh pacman database and update out of date packages
* Install pacman packages
* Install packages from arch user repo
* Install `yay` and update packages
* install packages with `yay`


