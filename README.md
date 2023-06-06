 # CraftCeres

This repository contains the configuration files for the PaperMC Java server, the automation scripts that the machine uses to perform maintenance tasks, and the website itself. The "server" folder contains only the files that have been altered from those PaperMC auto-generated. Inside the folder, any child directory will be as-is so that on a fresh installation, this repository can be cloned in order for the server to be pre-configured, only auto-generating those that don't need further configuration.

## updater.sh

_The Updater script is in charge of updating the server with the latest PaperMC build on a weekly basis._

Currently supports Minecraft updates only up to version 1.99.9.\
Designed to update _any_ PaperMC server setup. It should be run with `sudo` unless set as a cron job since PaperMC is (or should be) run by a user with limited permissions.\
\
The Updater relies on the following dependencies to work:[^1]

 - `tmux`[^2]
 - `curl`
 - `wget`
 - [`Java 17 Amazon Coretto`](https://docs.aws.amazon.com/corretto/latest/corretto-17-ug/downloads-list.html)


[^1]:Note that it will not work **at all** if they are not present in the system, exiting with the corresponding error.
[^2]:Both the Updater and the Backer assume you use a `tmux` session for the server, not only because that's how _I_ have set it up, but because the only way to interact with a running Java server and see previous logs in its console (from other devices) is through a terminal multiplexer.

### The Reporter

There's an optional feature in the Updater[^3] which allows the script to send a message through your own Telegram bot that reports the status in which the script exited, that is if it successfully executed or exited due to an error.

[^3]:The definition of the corresponding paths as well as the enabling of the reporter should be made on the 'updater.cfg' file.

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
