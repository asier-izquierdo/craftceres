# CraftCeres

This repository contains the configuration files for the PaperMC java server, the automation scripts that the machine uses to perform mainteinance tasks, and the website itself.

## updater.sh

Cron job running at [0 7 * * 1]<br>
Currently supports Minecraft updates only up to version 1.29.9 due to the PaperMC API returning 1.30+ values that made `sort` inaccurately list the latest version.
Designed to update any PaperMC server setup. It should be run with `sudo` unless set as a cron job since PaperMC is (or should be) run by an user with limited permissions.

### Limitations

- The updater doesn't currently support restarting the server with the previous functional build of PaperMC if the execution fails with exit code 4.
- The updater doesn't currently delete or archive previous builds of PaperMC.

## backer.sh

Cron job running at [0 21 * * 0,4], should be run with `sudo`, too.

### Limitations

- The backer doesn't currently back up Dynmap's MySQL database.
- The backer doesn't currently restart the server if the execution stops due to an error.
