#!/bin/bash

logfile="<path to log file>"
jarroute="<path to papermc.jar parent diretory>"
tmuxsession="<name of the tmux session where papermc is running>"

if [ ! -f $logfile ]
then
        echo "[INFO] [$(date)] Created log for the PaperMC updater script." > $logfile
fi

echo "[INFO] [$(date)] Starting script execution..." >> $logfile

version=$(curl https://papermc.io/downloads/paper | grep -Eo "1\.[1-2][0-9]\.[0-9]" | sort -r | head -1)

latest=$(curl https://api.papermc.io/v2/projects/paper/versions/$version/builds/ | grep -Eo '"build":[0-9]{1,4}' | sort -r | head -1 | cut -d: -f 2)

current=$(find $jarroute -name "paper-$version*" 2> /dev/null | grep -Eow "[0-9]{3,4}" | sort -r | head -1)

if [[ $current -lt $latest ]]
then

        if [[ -n $(pidof java) ]]
        then
                tmux send-keys -t $tmuxsession:0 "stop" Enter
                sleep 20
                wget https://api.papermc.io/v2/projects/paper/versions/$version/builds/$latest/downloads/paper-$version-$latest.jar -P $jarroute
        else
                echo "[WARNING: 2] [$(date)] The PaperMC server was not running." >> $logfile
                exit 2
        fi

        if [ -f $jarroute/paper-$version-$latest.jar ]
        then
                sleep 20
                tmux send-keys -t $tmuxsession:0 "java -Xmx2G -Xms16G -jar $jarroute/paper-$version-$latest.jar nogui" Enter

                if [[ -z $(pidof java) ]]
                then
                        echo "[ERROR: 4] [$(date)] The server failed to start using the latest PaperMC build." >> $logfile
                        exit 4
                fi

        else
                echo "[ERROR: 3] [$(date)] The latest PaperMC version could not be downloaded." >> $logfile
                exit 3
        fi

else
        echo "[INFO: 1] [$(date)] There were no updates for the server." >> $logfile
        exit 1

fi

echo "[INFO: 0] [$(date)] The PaperMC server has successfully been updated and restarted." >> $logfile

exit 0
