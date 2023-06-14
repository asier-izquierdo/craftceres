# updater.sh

_The Updater script is in charge of updating the server with the latest PaperMC build on a weekly basis._

Currently supports Minecraft updates only up to version 1.99.9.\
Designed to update _any_ PaperMC server setup. It should be run with `sudo` unless set as a cron job since PaperMC is (or should be) run by a user with limited permissions.\
\
The Updater relies on the following packages to work:[^1]

 - `tmux`[^2]
 - `curl`
 - `jq`[^3]
 - `wget`
 - [`Java 17 Amazon Coretto`](https://docs.aws.amazon.com/corretto/latest/corretto-17-ug/downloads-list.html)

[^1]:Note that it will not work **at all** if they are not present in the system, exiting with the corresponding error.
[^2]:Both the Updater and the Backer assume you use a `tmux` session for the server, not only because that's how _I_ have set it up, but because the only way to interact with a running Java server and see previous logs in its console (from other devices) is through a terminal multiplexer.
[^3]:The `jq` package is used to better parse the PaperMC's API Json response in order to get the latest build available for the current version.

\
*The Updater uses the `updater.conf` file, which is in charge of defining the paths specific to each setup to best adapt to it. The reason behind using a separate file for this purpose is to seamlessly update the script without having to re-define the paths again. This file should be created by copying `configuration.example`.*

### The Reporter

There's an optional feature in the Updater[^4] which allows the script to send a message through your own Telegram bot that reports the status in which the script exited, that is, wether it successfully executed or if it exited due to an error.

[^4]:The definition of the corresponding paths as well as the enabling of the reporter should be made on the 'updater.cfg' file.
