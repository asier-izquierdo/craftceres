#!/bin/bash

# Modify these variables with the corresponding values
papermc_path="<path to the papermc.jar parent diretory>"
log_file_path="<log file path>"
tmuxsession="<name of the tmux session where papermc is running>"

archive=$papermc_path/archive

# Constants
PAPER_API_URL="https://api.papermc.io/v2/projects/paper"
MC_VERSION_REGEX="1\.[0-9]{2}\.[0-9]"
BUILD_NUMBER_REGEX="[0-9]{3,4}"

# Starts the PaperMC Java job with the specified build
server_starter() {
        handler "INFO" 0 "Restarting the server with the $1 build..."
        sleep 20
        tmux send-keys -t $tmuxsession:0 "java -Xmx16G -Xms2G -jar $papermc_path/paper-$mc_version-$2.jar nogui" Enter
}

# Sends a stop signal to the running Java job through Tmux
server_stopper() {
        tmux send-keys -t $tmuxsession:0 "stop" Enter
        sleep 20
}

# Handles errors and warnings, acting accordingly
handler() {
        local report_type=$1
        local report_code=$2
        local report_message=$3
         
        echo "[$report_type: $report_code  ($(date))] $report_message" >> $log_file_path
        
        # Restart the server with the previously used PaperMC build if there has been an error other than 3, 2, or
        # if it has been correctly executed (0)
        if [[ $report_code != 0 && $report_code != 2 && $report_code != 3 && $report_code != 7 && $report_code != 8 ]]
        then

                # If the previously used PaperMC build has been archived, move it back
                if [ ! -f $papermc_path/$current_build ]
                then mv $archive/$current_build $papermc_path
                fi

                server_starter "previous" $current_build
        fi

        # Exit the script only if the call was for an error
        if [[ $report_type == "ERROR" ]]
        then    exit $report_code
        else    return $report_code
        fi

}

# Verifies that the values specified for the path/session variables exist
check_input() {

        if [ ! -d $1 ]
        then    handler "ERROR" 8 "The specified path for $2 does not exist."
        fi

}

# Verifies that the required packages are present in the system
check_dependency() {
        command -v "$1" >/dev/null 2>&1 || {
                handler 7 "ERROR" "Missing dependency $1."
        }
}

# Get the current local PaperMC, Minecraft, and available PaperMC versions
get() {
        
        case $1 in
                mc_version)
                        mc_version=$(curl $PAPER_API_URL | grep -Eo $MC_VERSION_REGEX | sort -r | head -1)
                        ;;
                latest_build)
                        latest_build=$(curl $PAPER_API_URL/versions/$mc_version | grep -Eo $BUILD_NUMBER_REGEX | sort -r | head -1)
                        ;;
                current_build)
                        current_build=$(find $papermc_path -name "paper-$mc_version*" 2> /dev/null | grep -Eow $BUILD_NUMBER_REGEX | sort -r | head -1)
                        ;;
        esac

        if [ $? -ne 0 ]
        then    handler "ERROR" 9 "Couldn't determine '$1'."
        fi

return 0
}

# Creates the log file if it doesn't already exist on the specified path
if [ ! -f $log_file_path ]
then    echo "[INFO: 0  ($(date))] Created log for the PaperMC updater script." > $log_file_path
fi

handler "INFO" 0 "Starting updater execution..."

check_input $papermc_path '"papermc_path"'
check_input $log_file_path '"log_file_path"'

check_dependency "curl"
check_dependency "tmux"
check_dependency "java"
check_dependency "wget"

get "current_build"
get "latest_build"
get "mc_version"

# Creates the archive directory to store the previously used PaperMC build if it doesn't already exist
if [ ! -d $archive ]
then
        handler "INFO" 0 "No archives directory found. Creating it..."

        mkdir $archive 

        if [ $? -ne 0 ]
        then    handler "ERROR" 2 "Could not create the archives directory. It is necessary for archiving previously working .jars in a tidied manener."
        else    handler "INFO" 0 "Created directory for archiving the latest working PaperMC .jar"
        fi

fi

if [ -z "$current_build" ] || [ $current_build -lt $latest_build ]
then

        if [ -n "$(pidof java)" ]
        then
                server_stopper

                # Uses `check` to check, since using `$?` could lead to false positives
                if [ -z "$(pidof java)" ]
                then
                        wget https://api.papermc.io/v2/projects/paper/versions/$mc_version/builds/$latest_build/downloads/paper-$mc_version-$latest_build.jar -P $papermc_path

                        if [ $? -ne 0 ]
                        then    handler "ERROR" 5 "The latest PaperMC build could not be downloaded."
                        else    mv $current_build $archive
                        fi

                else    handler "ERROR" 3 "The server failed to stop."
                fi

        else    handler "WARNING" 1 "The PaperMC server was not running." >> $log_file_path
        fi

        if [ -f $papermc_path/paper-$mc_version-$latest_build.jar ]
        then
                server_starter "latest" $latest_build

                if [ -z "$(pidof java)" ]
                then    handler "ERROR" 6 "The server failed to start using the latest PaperMC build."
                fi

        else    handler "ERROR" 4 "The latest PaperMC version could not be found."
        fi

        handler "INFO" 0 "The PaperMC server has successfully been updated and restarted."

else    handler "INFO" 0 "There were no updates for the server."

fi

return 0
