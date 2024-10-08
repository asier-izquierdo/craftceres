# updater.sh

_The Updater script is designed to be a one-time set-up that is periodically run to keep our server up to date._

Currently supports Minecraft updates only up to version 1.99.99.\
Designed to update _any_ Linux PaperMC server setup. It should be run with `sudo` unless set as a cron job since PaperMC is (or should be) run by a user with limited permissions.

If set as a cron job, the format should be as follows:\
`* * * * * CRON=true /path-to-script/updater.sh`\
Naturally, you should substitute the asterisks for whatever periodicity you may need, but you have to set the CRON enviromental variable because this is what will tell the script that is running automatically, and should log its events.

The Updater relies on the following packages to work:[^1]

 - `tmux`[^2]
 - `curl`
 - `jq`[^3]
 - `wget`
 - [`Java 21 Amazon Coretto`](https://docs.aws.amazon.com/corretto/latest/corretto-21-ug/downloads-list.html)

[^1]:Note that it will not work **at all** if they are not present in the system, exiting with the corresponding error.
[^2]:Both the Updater and the Backer assume you use a `tmux` session for the server, not only because that's how _I_ have set it up, but because the only way to interact with a running Java server and see previous logs in its console (from other devices) is through a terminal multiplexer.
[^3]:The `jq` package is used to better parse the PaperMC's API Json response in order to get the latest build available for the current version.


## The configuration file

*The Updater uses the `updater.conf` file, which is in charge of defining the paths specific to each setup to best adapt to it. The reason behind using a separate file for this purpose is to seamlessly update the script without having to re-define the paths again. This file should be created by copying and renaming `configuration.example`.*

The `configuration.example` file uses a YAML-like format, that the updater parses with [Stefan Farestam's YAML parser function](https://stackoverflow.com/questions/5014632/how-can-i-parse-a-yaml-file-from-a-linux-shell-script/21189044#21189044) through `sed` and `awk`.
Indentation is very important, so you should not modify anything but the actual value, with a space between the ':' and the value itself.

There are two sets of configuration groups, one required for the script to work, and the other optional to enable aditional features.

**The required block:**
```
# Required settings

papermc:  
  path: <path to the papermc.jar parent directory>
tmux_session:
  name: <name of the tmux session where papermc is running>
  path: <path to the tmux session location>'
```
consists on the 'papermc' path, that is, the parent directory under which the server files are located, and the `tmux` session information.\
All of the configuration paths **must** be absolute, and **it is sensible that they doesn't end with a slash**, so (using the papermc path as an example):

 - `path: /home/user/craftceres` is a valid definition.
 - `path: /home/user/craftceres/` is NOT a valid definition.

The `tmux` session information consists on the name you gave (or have to give) the session created for the server, since that's an accurate way to interact with it, and the path under which the session data is located. The name should be able to be defined using double quotes, according to the parser function's author, but I have not tested it.

The path of the session is necessary, since tmux doesn't work under "generic" paths but it rather names the path after the user that created the sessions. This means that if you create the `tmux` session with your regular user, and then the script will execute with root, root won't be able to locate the session by name, hence the need to define the session path.\
Under Red-Hat based distributions, the path usually is `/tmp/tmux-UID/default `, where "UID" refers to the UID of the user that created the `tmux` session. Other distributions have not been tested, but it shouldn't be hard to find their path.

**The optional block:**
```
# Optional settings

experimental_builds:
  enabled: <yes/no>
discord_reporter:
  enabled: <yes/no>
  webhook: <Discord's WebHook URL>
  adminid: <Admin's UID to mention>
telegram_reporter:
  enabled: <yes/no>
  id: <ID of the chat with the bot>
  token: <JUST the token found on the bot's URL (https://api.telegram.org/botTOKEN/sendMessage)>
```
consists on optional features that can optionally be enabled: To allow experimental builds, the Discord reporter and the Telegram reporter configuration, whose descriptions you can find further below. The optional functions use an aditional parameter "enabled" to indicate wether to use it or not.

- The experimental buids option signals the script to use PaperMC's unstable builds. Enabling this option __is risky__ and performance problems and bugs are to be expected, nevertheless, it's convenient to have the option both for test purposes and demanding (although naive) users.

### The Reporter

There's an optional feature in the Updater[^4] which allows the script to send a message via WebHook for Discord or using your own Telegram bot[^5] that reports the status in which the script exited, that is, wether it successfully executed or if it exited due to an error.

The Discord reporter doesn't need `adminid` unless the intention is to ping the admin and the current script doesn't since it mentions everyone (because the CraftCeres Discord has an administration channel for admins/mods). 

The Telegram reporter, needs all elements to be properly set in order for it to work.

- `id` should contain the ID of the chat with the bot you created.
- `token` should contain the API token for the bot, found in the URL with the format:\
~~(https://)api.telegram.org/bot~~TOKEN/~~sendMessage~~

[^4]:The definition of the corresponding paths as well as the enabling of the reporter should be made on the 'updater.cfg' file.
[^5]:Creating a Telegram bot is a simple process that can be achieved following [their official tutorial](https://core.telegram.org/bots/tutorial)
