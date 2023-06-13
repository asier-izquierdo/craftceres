 # CraftCeres

This repository contains the configuration files for the PaperMC Java server, the automation scripts that the machine uses to perform maintenance tasks, and the website itself. The "server" folder contains only the files that have been altered from those PaperMC auto-generated. Inside the folder, any child directory will be as-is so that on a fresh installation, this repository can be cloned in order for the server to be pre-configured, only auto-generating those that don't need further configuration.

## backer.sh

_The Backer script is (or should be) in charge of backing up both the world and the Dynmap's MySQL database to an external storage._

Should be run with `sudo` as well.

### Limitations

It doesn't currently back up Dynmap's MySQL database.
In fact, it doesn't currently work nor has it been tested, just here for version control.
## reverse-proxy.conf

This is just the configuration file that Nginx uses to pass the requests to either the webpage or the Dynmap service.

#

CraftCeres runs thanks to [PaperMC](https://github.com/PaperMC).\
The map is generated and served with [Dynmap](https://github.com/webbukkit/dynmap).\
The webpage uses the [mcstatus API](https://mcstatus.io/) to ping the server for the status bar.
