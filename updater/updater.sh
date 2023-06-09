#!/bin/bash

# Determines the absoulte path in which the script is located
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})

# Constants, ordered by likeliness of change
PAPER_API_URL="https://api.papermc.io/v2/projects/paper"
MC_VERSION_REGEX="1\.[0-9]{2}\.{0,1}[0-9]{0,2}"
BUILD_NUMBER_REGEX="[0-9]{1,4}"
LOG="$SCRIPT_DIR/updater.log"
CONF="$SCRIPT_DIR/updater.conf"
ARCHIVE="$papermc_path/archive"

# ########################### #
# Start of optional functions #
# ########################### #

# Sends a message to Telegram reporting the script's outcome.
reporter() {

        # Check if bot_url and chat_id are set
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

                curl -s -X POST "$bot_url" -d chat_id=$chat_id -d text="$script_result" >/dev/null 2>&1
        else    handler "WARNING" 17 "The reporter is not enabled. To enable it, please set both <bot_url> and <chat_id>. No notifications were sent."
        fi

return 0
}

# ########################## #
# Start of regular functions #
# ########################## #

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
        if [ ! -f $LOG ]
        then    echo "[$timestamp] INFO: 0 > Created log for the PaperMC updater script." > $LOG
        fi

        # Verbose progress and errors instead of logging them if the execution is manual instead of a cron job
        if [ -n '$PS1' ]
        then    echo -e "$entry"
        else    echo -e "$entry" >> $LOG
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
        if [[ (! -f $papermc_path/paper-*-$current_build.jar) && (-f $ARCHIVE/paper-*-$current_build.jar) ]]
        then    mv $ARCHIVE/paper-*-$current_build.jar $papermc_path
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
    then        handler "ERROR" 3 "The specified path for $2 does not exist."
    elif [[ $2 == "<tmuxsession>" ]]
    then
                tmux -S $tmux_session_path has-session -t $1 2> /dev/null

                if [ $? -ne 0 ]
                then    handler "ERROR" 4 "The specified tmux session '"$1"' does not exist."
                fi

    fi

return 0
}

# Verifies that the required packages are present in the system
check_dependency() {
        command -v "$1" >/dev/null 2>&1 || {
                handler "ERROR" 5 "Missing dependency <$1>."
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
                latest_build=$(curl -s "$PAPER_API_URL/versions/$mc_version" | jq -r '.builds[]' | sort -rn | head -1)
                ;;
        current_build)
                handler "INFO" 0 "Checking currently used PaperMC build..."
                current_build=$(find $papermc_path -name "paper-*" -maxdepth 1 2> /dev/null | grep -Eo "[0-9]\-$BUILD_NUMBER_REGEX\." | grep -Eo "$BUILD_NUMBER_REGEX\." | grep -Eo "$BUILD_NUMBER_REGEX")
                ;;
        esac

        if [[ ($? != 0) || (-z "$$1") ]]
        then    handler "ERROR" 6 "Could not determine '$1'."
        fi

return 0
}

# Fetches the latest build and archives the previous one
download_latest_build() {
        handler "INFO" 0 "Downloading the latest PaperMC build..."

        wget -q $LATEST_BUILD_LINK -P $papermc_path

        if [ $? -ne 0 ]
        then    handler "ERROR" 7 "The latest PaperMC build could not be downloaded."
        else

                if [ -n "$current_build" ]
                then
                        handler "INFO" 0 "Archiving previous build..."

                        mv $papermc_path/paper-*-$current_build.jar $ARCHIVE

                        if [ $? -eq 0 ]
                        then    handler "INFO" 0 "Successfully moved the previous build to the archive."
                        else    handler "WARNING" 13 "Could not move the previous build to the archive."
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
                # Gets the whole file name of the oldest and the newest files on the archive
                local oldest=$(ls $ARCHIVE | sort -rV | grep 'paper-*' | tail -1)
                local newest=$(ls $ARCHIVE | sort -rV | grep 'paper-*' | head -1)

                # Gets the version and build from the file name (i.e. '1.20.1-18')
                local oldest_version=$(echo $oldest | grep -oE "$MC_VERSION_REGEX-[0-9]{1,4}")
                local newest_version=$(echo $newest | grep -oE "$MC_VERSION_REGEX-[0-9]{1,4}")

                # Gets the release number from the version (from the last example, the '20')
                local oldest_release=$(echo $oldest_version | grep -oE "\.[0-9]+\." | grep -oE "[0-9]+")
                local newest_release=$(echo $newest_version | grep -oE "\.[0-9]+\." | grep -oE "[0-9]+")

                # Gets the update number from the version (from the first example, the last '1')
                local oldest_update=0
                local oldest_update=$(echo $oldest_version | grep -E "$oldest_release\." | grep -oE "\.[0-9]+-" | grep -oE "[0-9]+")
                local newest_update=0
                local newest_update=$(echo $newest_version | grep -E "$newest_release\." | grep -oE "\.[0-9]+-" | grep -oE "[0-9]+")

                # Gets the build number from the version (from the first example, the '18')
                local oldest_build=$(echo $oldest_version | grep -oE "\-[0-9]+" | grep -oE "[0-9]+")
                local newest_build=$(echo $newest_version | grep -oE "\-[0-9]+" | grep -oE "[0-9]+")

                # Compares each number of the file to check if they all are lesser than the newest update, if any number is greater,
                # then the version that is trying to be archived is not newer, thus discarding it
                if [[ ($oldest_release -le $newest_release) && ($oldest_update -le $newest_update) && ($oldest_build -lt $newest_build) ]]
                then
                        rm $ARCHIVE/$oldest

                        if [ $? -eq 0 ]
                        then    handler "INFO" 0 "Successfully removed the older build '$oldest' from the archive."
                        else    handler "WARNING" 14 "Could not remove the older build '$oldest' from the archive."
                        fi

                else    handler "WARNING" 15 "There is clutter on the archive, but the version is not lower than the previously archived one."
                fi

        else    handler "WARNING" 16 "There was not anything to remove from the archive."
        fi

return 0
}

# ######################### #
# Start of script execution #
# ######################### #

# Checks if the configuration file is available, the even isn't logged because without the configuration, no log file is defined
if [[ ! -f $CONF ]]
then    handler "ERROR" 1 "The configuration could not be found, this may be due to a wrongly defined path or to the file not existing. Please, provide a valid configuration path."    
else    source $CONF
fi

# Checks if every required variable from the configuration is set, that is, everything but the reporter's
if [[ -z "$papermc_path" || -z "$tmux_session_name" || -z "$tmux_session_path" ]]
then    handler "ERROR" 2 "One or more of the configuration variables are unset; note that, except 'bot_url' and 'chat_id', all variables are required in order for the updater to work properly."
fi

handler "INFO" 0 "Starting the updater execution..."

check_dependency "curl"
check_dependency "jq"
check_dependency "tmux"
check_dependency "java"
check_dependency "wget"

check_input $papermc_path "<papermc_path>"
check_input $tmux_session_name "<tmuxsession>"

get "mc_version"
get "latest_build"
get "current_build"
LATEST_BUILD_LINK="$PAPER_API_URL/versions/$mc_version/builds/$latest_build/downloads/paper-$mc_version-$latest_build.jar"

# Creates the archive directory to store the previously used PaperMC build if it doesn't already exist
if [ ! -d $ARCHIVE ]
then
        handler "INFO" 0 "No archive directory found. Creating it..."

        mkdir $ARCHIVE

        if [ $? -ne 0 ]
        then    handler "ERROR" 8 "Could not create the archives directory. It is necessary for archiving previously working .jars in a tidied manner."
        else    handler "INFO" 0 "Created directory for archiving the latest working PaperMC .jar"
        fi

fi

# Checks if there's no installation or if the current is an older version in order to determine wether the updating process should trigger
if [ -z "$current_build" ] || [ $current_build -lt $latest_build ]
then

        if [ -n "$(pidof java)" ]
        then
                server_stopper

                # Uses `check` to check, since using `$?` could lead to false positives
                if [ -n "$(pidof java)" ]
                then    handler "ERROR" 9 "The server failed to stop."
                fi

        else    handler "WARNING" 12 "The PaperMC server was not running."
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
                        handler "ERROR" 10 "The server failed to start using the latest PaperMC build."
                fi

        else    handler "ERROR" 11 "The latest PaperMC version could not be found on the system."
        fi

        handler "INFO" 0 "The PaperMC server has successfully been updated and restarted."
        reporter "OK" ", and the server has correctly been updated and restarted."
        unclutterer
else
        handler "INFO" 0 "There were no updates for the server."
        reporter "OK" "; however, there were no updates for the server."
fi
