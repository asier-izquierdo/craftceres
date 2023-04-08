# CraftCeres

This repository contains the configuration files for the PaperMC java server, the automation scripts that the machine uses to perform mainteinance tasks, and the website itself.<br>
The "server" folder contains only the files that have been altered from those PaperMC auto-generated. Inside the folder, any child directory will be as-is, so that on a fresh installation, this repository can be cloned in order for server to be pre-configured, only auto-generating those that don't need further configuration.
## updater.sh

__The updater script is in charge of updating the server with the latest PaperMC build in a weekly basis.__

The cron job is running at [0 7 * * 1]<br>
Currently supports Minecraft updates only up to version 1.29.9 due to the PaperMC API returning 1.30+ values that made `sort` inaccurately list the latest version.<br>
Designed to update _any_ PaperMC server setup. It should be run with `sudo` unless set as a cron job since PaperMC is (or should be) run by an user with limited permissions.

### Limitations

- It doesn't currently support restarting the server with the previous functional build of PaperMC if the execution fails with exit code 4.
- It updater doesn't currently delete or archive previous builds of PaperMC.

## backer.sh

__The backer script is (_or should be_) in charge of backing up both the world and the Dynmap's MySQL database.__

Cron job running at [0 21 * * 0,4]. Should be run with `sudo`, too.

### Limitations

- The backer doesn't currently back up Dynmap's MySQL database.

## reverse-proxy.conf

This is just the configuration file that Nginx uses in order to pass the requests to either the webpage or the Dynmap service.

#

CraftCeres runs thanks to [PaperMC](https://github.com/PaperMC).<br>
The map is generated and served with (Dynmap)[https://github.com/webbukkit/dynmap].<br>
The webpage uses [minestat](https://github.com/FragLand/minestat) to ping the server for the status bar.
