#!/bin/bash

# Modify these variables with the fitting values
logfile="<path to log file>"
archive="<path to archives directory>"
jarroute="<path to papermc.jar parent diretory>"
tmuxsession="<name of the tmux session where papermc is running>"

# Get the current local PaperMC, Minecraft, and available PaperMC versions, respectively.
current=$(find $jarroute -name "paper-$version*" 2> /dev/null | grep -Eow "[0-9]{3,4}" | sort -r | head -1)
version=$(curl https://papermc.io/downloads/paper | grep -Eo "1\.[1-2][0-9]\.[0-9]" | sort -r | head -1)
latest=$(curl https://api.papermc.io/v2/projects/paper/versions/$version/builds/ | grep -Eo '"build":[0-9]{1,4}' | sort -r | head -1 | cut -d: -f 2)

error_handler() {
    local error_code=$1
    local error_message=$2
    echo "[ERROR: $error_code  ($(date))] $error_message" >> $logfile
    exit $error_code
}

if [ ! -f $logfile ]
then    echo "[INFO  ($(date))] Created log for the PaperMC updater script." > $logfile
fi

echo "[INFO  ($(date))] Starting updater execution..." >> $logfile

if [ ! -d $archive ]
then
        echo "[INFO  ($(date))] No archives directory found. Creating it..." >> $logfile

        mkdir $archive 

        if [ $? -ne 0 ]
        then    error_handler X "Could not create the archives directory. It is necessary for archiving previously working .jars in a tidied manener."
        else    echo "[INFO  ($(date))] Created directory for archiving the latest working PaperMC .jar" >> $logfile
        fi

fi

if [[ $current -lt $latest ]]
then

        if [ -n $(pidof java) ]
        then
                tmux send-keys -t $tmuxsession:0 "stop" Enter
                sleep 20

                if [ -z $(pidof java) ]
                then
                        wget https://api.papermc.io/v2/projects/paper/versions/$version/builds/$latest/downloads/paper-$version-$latest.jar -P $jarroute

                        if [ $? -ne 0 ]
                        then    error_handler X "The latest PaperMC build could not be downloaded."
                        else    mv $current $archive
                        fi

                else    error_handler X "The server failed to stop."
                fi

        else    echo "[WARNING:  ($(date))] The PaperMC server was not running." >> $logfile
        fi

        if [ -f $jarroute/paper-$version-$latest.jar ]
        then
                sleep 20
                tmux send-keys -t $tmuxsession:0 "java -Xmx2G -Xms16G -jar $jarroute/paper-$version-$latest.jar nogui" Enter

                if [[ -z $(pidof java) ]]
                then    error_handler X "The server failed to start using the latest PaperMC build."
                fi

        else    error_handler X "The latest PaperMC version could not be found."
        fi

        echo "[INFO: 0  ($(date))] The PaperMC server has successfully been updated and restarted." >> $logfile
        exit 0

else
        echo "[INFO: 1  ($(date))] There were no updates for the server." >> $logfile
        exit 1

fi
