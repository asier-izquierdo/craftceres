#!/bin/bash

# Modify these variables with the fitting values
path="<path to the papermc.jar parent diretory>"
logfile="<path to log file>"
tmuxsession="<name of the tmux session where papermc is running>"

# Constants
PAPER_DOWNLOAD_URL="https://papermc.io/downloads/paper"
PAPER_API_URL="https://api.papermc.io/v2/projects/paper"
MC_VERSION_REGEX="1\.[1-2][0-9]\.[0-9]"
BUILD_NUMBER_REGEX="[0-9]{3,4}"

# Get the current local PaperMC, Minecraft, and available PaperMC versions, respectively.
archive=$path/archive
current=$(find $path -name "paper-$version*" 2> /dev/null | grep -Eow "[0-9]{3,4}" | sort -r | head -1)
version=$(curl $PAPER_DOWNLOAD_URL | grep -Eo $MC_VERSION_REGEX | sort -r | head -1)
latest=$(curl $PAPER_API_URL/versions/$version/builds/ | grep -Eo '"build":\$BUILD_NUMBER_REGEX' | sort -r | head -1 | cut -d: -f 2)

server_starter() {
        handler "INFO" 0 "Restarting the server wit the $1 build..."
        sleep 20
        tmux send-keys -t $tmuxsession:0 "java -Xmx2G -Xms16G -jar $path/paper-$version-$2.jar nogui" Enter
}

handler() {
        local report_type=$1
        local report_code=$2
        local report_message=$3
         
        echo "[$report_type: $report_code  ($(date))] $report_message" >> $logfile
        
        # If there has been an error other than 3, restart the server with the previously used PaperMC build
        if [[ $report_code != 0 && $report_code != 2 && $report_code != 3 ]]
        then

                # If the previously used PaperMC build has been archived, move it back
                if [ ! -f $path/$current ]
                then mv $archive/$current $path
                fi

                server_starter "previous" $current
        fi

        # Exit the script only if an error happens
        if [[ $report_type == "ERROR" ]]
        then    exit $report_code
        else    return $report_code
        fi

}

check_dependency() {
  command -v "$1" >/dev/null 2>&1 || {
    handler 7 "ERROR" "Missing dependency $1."
  }
}

check_dependency "curl"
check_dependency "tmux"
check_dependency "java"
check_dependency "wget"

# Create the log file if it doesn't already exist on the specified path
if [ ! -f $logfile ]
then    echo "[INFO: 0  ($(date))] Created log for the PaperMC updater script." > $logfile
fi

handler "INFO" 0 "Starting updater execution..."

# Create the archive directory to store the previously used PaperMC build if it doesn't already exist
if [ ! -d $archive ]
then
        handler "INFO" 0 "No archives directory found. Creating it..."

        mkdir $archive 

        if [ $? -ne 0 ]
        then    handler "ERROR" 2 "Could not create the archives directory. It is necessary for archiving previously working .jars in a tidied manener."
        else    handler "INFO" 0 "Created directory for archiving the latest working PaperMC .jar"
        fi

fi

if [ $current -lt $latest ]
then

        if [ -n "$(pidof java)" ]
        then
                tmux send-keys -t $tmuxsession:0 "stop" Enter
                sleep 20

                if [ -z "$(pidof java)" ]
                then
                        wget https://api.papermc.io/v2/projects/paper/versions/$version/builds/$latest/downloads/paper-$version-$latest.jar -P $path

                        if [ $? -ne 0 ]
                        then    handler "ERROR" 5 "The latest PaperMC build could not be downloaded."
                        else    mv $current $archive
                        fi

                else    handler "ERROR" 3 "The server failed to stop."
                fi

        else    handler "WARNING" 1 "The PaperMC server was not running." >> $logfile
        fi

        if [ -f $path/paper-$version-$latest.jar ]
        then
                server_starter "latest" $latest

                if [ -z "$(pidof java)" ]
                then    handler "ERROR" 6 "The server failed to start using the latest PaperMC build."
                fi

        else    handler "ERROR" 4 "The latest PaperMC version could not be found."
        fi

        handler "INFO" 0 "The PaperMC server has successfully been updated and restarted."

else    handler "INFO" 0 "There were no updates for the server."

fi
