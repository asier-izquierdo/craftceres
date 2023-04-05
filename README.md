# CraftCeres

This repository contains the configuration files used for the CraftCeres Minecraft server, running with PaperMC.

## updater.sh

Designed to be run as a cron job (currently running at 0 7 * * 1) with root permissions, since PaperMC is (or should be) run by an user with limited permissions.<br>
Currently supports Minecraft updates only up to version 1.29.9 due to the PaperMC API returning 1.30+ values that made `sort` inaccurately list the latest version.

### Limitations

- The updater doesn't currently support restarting the server with the previous functional build of PaperMC if the execution fails with exit code 4.
- The updater doesn't currently delete or archive previous builds of PaperMC.
