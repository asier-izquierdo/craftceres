 # CraftCeres

This repository contains the configuration files for the PaperMC Java server, the automation scripts that the machine uses to perform maintenance tasks, and the website itself. The "server" folder contains only the files that have been altered from those PaperMC auto-generated. Inside the folder, any child directory will be as-is so that on a fresh installation, this repository can be cloned in order for the server to be pre-configured, only auto-generating those that don't need further configuration.

The "Updater" folder contains files for a script that updates PaperMC to the latest version in the time of execution.

The "Backer" folder will contain files for a script that will automatically handle backups.

".example" files such as the following "health.example" should be copied with another name prior to entering personal details so that the originals remain for reference.

## health.example

Example file of a little helper script designed to be set up as a cron job running in short periods of time to alert through Discord in case the server unexpectedly stops.
It has a little control system to only alert once per fail, to not spam.

## reverse-proxy.conf

This is just the configuration file that Nginx uses to pass the requests to either the webpage or the Dynmap service.

#

CraftCeres runs thanks to [PaperMC](https://github.com/PaperMC).\
The map is generated and served with [Dynmap](https://github.com/webbukkit/dynmap).\
The webpage uses the [mcstatus API](https://mcstatus.io/) to ping the server for the status bar.
