#!/bin/bash

logfile="<path to log file>"
tmuxsession="<name of the tmux session where papermc is running>"
backdir="<path to backups directory>"
pdir="<path to parent directory for the data to back up>"
ruser="<remote user for rsync>"
rhost="<remote host for rsync>"
rdir="<path to the backups directory of the remote host>"

if [ ! -f $logfile ]
then
        echo "[INFO] [$(date)] Created log for the PaperMC backer script." > $logfile
fi

echo "[INFO] [$(date)] Starting backer execution..." >> $logfile

if [[ -n $(pidof java) ]]
then
        tmux send-keys -t $tmuxsession:0 "stop" Enter
        sleep 20
else
        echo "[WARNING: 1] [$(date)] The PaperMC server was not running. A backup will still be made." >> $logfile
        exit 1
fi

if [[ -z $(pidof java) ]]
then
            
        if [ ! -d $backdir ]
        then
                echo "[INFO] [$(date)] Created directory "backups" for the PaperMC backer script." >> $logfile
        fi

        tar -czf $backdir/$(date +%Y-%m-%d_%H-%M-%S).tar.gz $pdir/world $pdir/world_nether $pdir/world_the_end

        if [ $? -eq 0 ]
        then
                echo "[INFO] [$(date)] A backup of the world has successfully been created." >> $logfile
                rsync -av --delete -e "ssh" "$backdir" "$ruser@$rhost:$rdir"

                if [ $? -ne 0 ] 
                then
                        echo "[ERROR 5] [$(date)] The backup could not be transfrered to the destination host." >> $logfile
                        exit 5
                else    
                        echo "[INFO] [$(date)] The backup has successfully been transferred to the destination host" >> $logfile
                fi

        else
                echo "[ERROR: 4] [$(date)] The world backup failed." >> $logfile  
                exit 4
        fi

else
        echo "[ERROR: 2] [$(date)] The PaperMC server did not stop, could not create a backup." >> $logfile 
        exit 2
fi

sleep 20
tmux send-keys -t $tmuxsession:0 "java -Xmx2G -Xms16G -jar $jarroute/paper-$version-$latest.jar nogui" Enter

if [ $? -eq 0 ]
then 
        echo "[INFO: 0] [$(date)] The world has successfully been backed up, transferred to the destination, and the server has successfully been restarted." >> $logfile
        exit 0
else
        echo "[ERROR: 3] [$(date)] The server could not restart." >> $logfile 
        exit 3
fi
