# backer.sh

_The Backer script is (or should be) in charge of backing up both the world and the Dynmap's MySQL database to an external storage._\
It should be run with `sudo` unless set as a cron job since PaperMC is (or should be) run by a user with limited permissions.

### Limitations

It doesn't currently back up Dynmap's MySQL database.
In fact, it doesn't currently work nor has it been tested, just here for version control.
