#!/bin/bash

# Modify these variables with the corresponding values (do not use "/" after a directory)
papermc_path="<path to the papermc.jar parent directory>"
log_file_path="<log file path>" # Include your desired log file name ('/path/name.log')
tmux_session_name="<name of the tmux session where papermc is running>"
tmux_session_path="<path to the tmux session location>" # Usually '/tmp/tmux-<UID_of_the_invoker>/default'

# Constants, ordered by likeliness of change
PAPER_API_URL="https://api.papermc.io/v2/projects/paper"
MC_VERSION_REGEX="1\.[0-9]{2}\.[0-9]"
BUILD_NUMBER_REGEX="[0-9]{3,4}"
ARCHIVE=$papermc_path/archive

# This is an optional function. Sends a message to Telegram reporting the script's outcome.
reporter() {
        # Uncomment the following local variables and define the corresponding values to enable
        # the reporter, otherwise it will just show a warning reporting that it is not enabled

        # local bot_url="https://api.telegram.org/botTOKEN/sendMessage"
        # local chat_id="<ID of the chat with the bot>"

        if [[ (-n $bot_url) && (-n $chat_id) ]]
        then

                case $1 in
                OK)
                        local script_result=$(echo -e "The Updater executed$2")
                        ;;
                NOT)
                        local script_result=$(echo -e "The Updater executed; however, there has been a problem. Here is the log entry:\n\n$2")
                        ;;
                esac

                curl -s -X POST "$bot_url" -d chat_id=$chat_id -d text="$script_result"
        else    handler "WARNING" 15 "The reporter is not enabled. To enable it, please set both <bot_url> and <chat_id>. No notifications were sent."
        fi

return 0
}

# Starts the PaperMC Java job with the specified build
server_starter() {
        handler "INFO" 0 "Starting the server with the $1 build..."
        sleep 20
        tmux -S $tmux_session_path send-keys -t $tmux_session_name:0 "(cd $papermc_path && java -Xms2G -Xmx16G -jar $papermc_path/paper-$mc_version-$2.jar nogui)" Enter

return 0
}


# Sends a stop signal to the running Java job through Tmux
server_stopper() {
        handler "INFO" 0 "Stopping the server..."
        tmux -S $tmux_session_path send-keys -t $tmux_session_name:0 "stop" Enter
        sleep 20

return 0
}

# Actually records entries to the log, plus colors them to easly differenciate severity
log_entry() {
        local timestamp=$(date +"%Y-%m-%d | %H:%M:%S")

        # ANSI escape codes for colors
        RED='\033[0;31m'
        YELLOW='\033[1;33m'
        GREEN='\033[0;32m'
        NC='\033[0m' # No color

        case $1 in
        "ERROR")
            color=$RED
            ;;
        "WARNING")
            color=$YELLOW
            ;;
        "INFO")
            color=$GREEN
            ;;
        *)
            color=$NC
            ;;
        esac

        # Formats the entry
        entry="[$timestamp] ${color}$1: $2 > $3${NC}"

        # Creates the log file if it doesn't already exist on the specified path
        if [ ! -f $log_file_path ]
        then    echo "[$timestamp] INFO: 0 > Created log for the PaperMC updater script." > $log_file_path
        fi

        # Verbose progress and errors instead of logging them if the execution is manual instead of a cron job
        if [ -n "$TERM" ]
        then    echo -e "$entry"
        else    echo -e "$entry" >> $log_file_path
        fi

return 0
}

# Handles errors and warnings, acting accordingly
handler() {
    local report_type=$1
    local report_code=$2
    local report_message=$3
    # List of the codes that will lead to a server restart 
    local restart_codes=(5 8 9)
    
    log_entry "$report_type" "$report_code" "$report_message"
    
    # Restart the server with the previously used PaperMC build if there has been an error contained in the array
    if [[ "${restart_codes[@]}" =~ $report_code ]]
    then

        # If the previously used PaperMC build has been archived, move it back
        if [[ (! -f $papermc_path/paper-$mc_version-$current_build.jar) && (-f $ARCHIVE/paper-$mc_version-$current_build.jar) ]]
        then    mv $ARCHIVE/paper-$mc_version-$current_build.jar $papermc_path
        fi

        server_starter "previous" $current_build
    fi

    # Exit the script only if the call was for an error
    if [[ $report_type == "ERROR" ]]
    then
            reporter "NOT" "$report_message"
            exit $report_code
    else    return $report_code
    fi

return 0
}

# Verifies that the values specified for the path/session variables exist
check_input() {

    if [[ (! -f $1) && (! -d $1) && ($2 != "<tmuxsession>") ]]
    then        handler "ERROR" 1 "The specified path for $2 does not exist."
    elif [[ $2 == "<tmuxsession>" ]]
    then
                tmux -S $tmux_session_path has-session -t $1 2> /dev/null

                if [ $? -ne 0 ]
                then    handler "ERROR" 2 "The specified tmux session '"$1"' does not exist."
                fi

    fi

return 0
}

# Verifies that the required packages are present in the system
check_dependency() {
        command -v "$1" >/dev/null 2>&1 || {
                handler "ERROR" 3 "Missing dependency <$1>."
        }

return 0
}

# Gets the current local PaperMC, Minecraft, and available PaperMC versions
get() {

        case $1 in
        mc_version)
                handler "INFO" 0 "Fetching current Minecraft version..."
                mc_version=$(curl -s $PAPER_API_URL | grep -Eo $MC_VERSION_REGEX | sort -r | head -1)
                ;;
        latest_build)
                handler "INFO" 0 "Fetching latest available PaperMC build..."
                latest_build=$(curl -s "$PAPER_API_URL/versions/$mc_version" | grep -Eo "$BUILD_NUMBER_REGEX" | sort -r | head -1)
                ;;
        current_build)
                handler "INFO" 0 "Checking currently used PaperMC build..."
                current_build=$(find $papermc_path -name "paper-$mc_version*" 2> /dev/null | grep -Eow $BUILD_NUMBER_REGEX | sort -r | head -1)
                ;;
        esac

        if [[ ($? != 0) || (-z "$$1") ]]
        then    handler "ERROR" 4 "Couldn't determine '$1'."
        fi

return 0
}

# Fetches the latest build and archives the previous one
download_latest_build() {
        handler "INFO" 0 "Downloading the latest PaperMC build..."

        wget -q $LATEST_BUILD_LINK -P $papermc_path

        if [ $? -ne 0 ]
        then    handler "ERROR" 5 "The latest PaperMC build could not be downloaded."
        else
        
                if [ -n "$current_build" ]
                then
                        handler "INFO" 0 "Archiving previous build..."

                        mv $papermc_path/paper-$mc_version-$current_build.jar $ARCHIVE

                        if [ $? -eq 0 ]
                        then    handler "INFO" 0 "Successfully moved the previous build to the archive."
                        else    handler "WARNING" 11 "Could not move the previous build to the archive."
                        fi

                fi

        fi

return 0
}

# The build that was archived in the previous execution (if any) is deleted to not clutter the archive
unclutterer() {
        handler "INFO" 0 "Checking if there is any surplus on the archive..."

        local count=$(ls -l $ARCHIVE | wc -l)

        if [ $count -gt 1 ]
        then
                local oldest=$(ls -t $ARCHIVE | grep 'paper-*' | tail -1)
                local newest=$(ls -t $ARCHIVE | grep 'paper-*' | head -1)
                local oldest_num=$(echo $oldest| grep -oE "[0-9]{3,4}" | head -1)
                local newest_num=$(echo $newest| grep -oE "[0-9]{3,4}" | head -1)

                if [ $oldest_num -lt $newest_num ]
                then
                        rm $ARCHIVE/$oldest

                        if [ $? -eq 0 ]
                        then    handler "INFO" 0 "Successfully removed the older build '$oldest' from the archive."
                        else    handler "WARNING" 12 "Could not remove the older build '$oldest' from the archive."
                        fi

                else    handler "WARNING" 13 "There is clutter on the archive, but the version isn't lower than the previously archived one."
                fi
        
        else    handler "WARNING" 14 "There was not anything to remove from the archive."
        fi

return 0
}

handler "INFO" 0 "Starting the updater execution..."

check_dependency "curl"
check_dependency "tmux"
check_dependency "java"
check_dependency "wget"

check_input $papermc_path "<papermc_path>"
check_input $log_file_path "<log_file_path>"
check_input $tmux_session_name "<tmuxsession>"

get "mc_version"
get "latest_build"
get "current_build"
LATEST_BUILD_LINK="https://api.papermc.io/v2/projects/paper/versions/$mc_version/builds/$latest_build/downloads/paper-$mc_version-$latest_build.jar"

# Creates the archive directory to store the previously used PaperMC build if it doesn't already exist
if [ ! -d $ARCHIVE ]
then
        handler "INFO" 0 "No archive directory found. Creating it..."

        mkdir $ARCHIVE

        if [ $? -ne 0 ]
        then    handler "ERROR" 6 "Could not create the archives directory. It is necessary for archiving previously working .jars in a tidied manner."
        else    handler "INFO" 0 "Created directory for archiving the latest working PaperMC .jar"
        fi

fi

if [ -z "$current_build" ] || [ $current_build -lt $latest_build ]
then

        if [ -n "$(pidof java)" ]
        then
                server_stopper

                # Uses `check` to check, since using `$?` could lead to false positives
                if [ -n "$(pidof java)" ]
                then    handler "ERROR" 7 "The server failed to stop."
                fi

        else    handler "WARNING" 10 "The PaperMC server was not running."
        fi

        download_latest_build

        if [ -f $papermc_path/paper-$mc_version-$latest_build.jar ]
        then
                server_starter "latest" $latest_build

                if [ -z "$(pidof java)" ]
                then
                        # If the server couldn't use the latest build, it removes it before restarting with the previous
                        # one, in order for another run of the script not to indicate that no updates were found
                        rm $papermc_path/paper-$mc_version-$latest_build.jar
                        handler "ERROR" 8 "The server failed to start using the latest PaperMC build."
                fi

        else    handler "ERROR" 9 "The latest PaperMC version could not be found on the system."
        fi

        handler "INFO" 0 "The PaperMC server has successfully been updated and restarted."
        reporter "OK" "and the server has correctly been updated and restarted."
        unclutterer
else
        handler "INFO" 0 "There were no updates for the server."
        reporter "OK" "; however, there were no updates for the server."
fi
