#!/bin/bash

# Determines the absoulte path in which the script is located
SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})

# Determines wether the script is being run manually or not
if [ -n '$PS1' ]
        then    exec_mode="manual"
        else    exec_mode="auto"
fi

# Constants, ordered by likeliness of change
PAPER_API_URL="https://api.papermc.io/v2/projects/paper"
MC_VERSION_REGEX="1\.[0-9]{2}\.{0,1}[0-9]{0,2}"
BUILD_NUMBER_REGEX="[0-9]{1,4}"
LOG="$SCRIPT_DIR/updater.log"
CONF="$SCRIPT_DIR/updater.conf"
ARCHIVE="$papermc_path/archive"
FLAGDIR="$SCRIPT_DIR/.hflag"

# ########################### #
# Start of optional functions #
# ########################### #

# Sends a message to Discord or Telegram reporting the script's outcome.
reporter() {

        # Check if the Discord reporter is enabled
        if [[ ( $discord_reporter_enabled == "yes" ) ]]
        then

                # Check if discord_reporter_webhook is set
                if [[ (-n $discord_reporter_webhook1) ]]
                then

                        case $1 in
                        OK)
                                local payload=$(cat <<EOF
{
        "content": "The Updater executed$2"
}
EOF
                                )
                                ;;
                        NOT)
                                local payload=$(cat <<EOF
{
        "content": "The Updater executed; however, there has been a problem. Here is the log entry:\n\n$2"
}
EOF
                                )
                                ;;
                        esac

                        curl -H "Content-Type: application/json" -X POST -d "$payload" $discord_reporter_webhook1 >/dev/null 2>&1
                else    handler "WARNING" 17 "The reporter is not correctly enabled. Please, set <discord_reporter_webhook1>. No notifications were sent."
                fi

                if [[ (-n $discord_reporter_webhook2) ]]
                then
                
                        case $1 in
                        UPDATED)
                                local payload=$(cat <<EOF
{
        "content": "¡El servidor se ha actualizado a la versión $mc_version, @everyone!"
}
EOF
                                )
                                curl -H "Content-Type: application/json" -X POST -d "$payload" $discord_reporter_webhook2 >/dev/null 2>&1
                                ;;
                        esac

                else handler "WARNING" 17 "The reporter is not correctly enabled. Please, set <discord_reporter_webhook2>. No notifications were sent."
                fi

        fi

        # Check if the Telegram reporter is enabled
        if [[ ( $telegram_reporter_enabled == "yes" ) ]]
        then

                # Check if telegram_reporter_token and telegram_reporter_id are set
                if [[ (-n $telegram_reporter_token) && (-n $telegram_reporter_id) ]]
                then

                        case $1 in
                        OK)
                                local script_result=$(echo -e "The Updater executed$2")
                                ;;
                        NOT)
                                local script_result=$(echo -e "The Updater executed; however, there has been a problem. Here is the log entry:\n\n$2")
                                ;;
                        esac

                        curl -s -X POST "https://api.telegram.org/bot$telegram_reporter_token/sendMessage" -d chat_id=$telegram_reporter_id -d text="$script_result" >/dev/null 2>&1
                else    handler "WARNING" 17 "The reporter is not correctly enabled. Please, set both <telegram_reporter_token> and <telegram_reporter_id>. No notifications were sent."
                fi

        fi

return 0
}

# ########################## #
# Start of regular functions #
# ########################## #

# Starts the PaperMC Java job with the specified build
server_starter() {
        handler "INFO" 0 "Starting the server with the $1 build..."
        sleep 30
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

# Handles errors and warnings, acting accordingly
handler() {
        local report_type=$1
        local report_code=$2
        local report_message=$3
        # List of the codes that will lead to a server restart 
        local restart_codes=(5 8 10)

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
                then echo "[$timestamp] INFO: 0 > Created log for the PaperMC updater script." > $LOG
                fi

                # Verbose progress and errors instead of logging them if the execution is manual instead of a cron job
                if [ $exec_mode == "manual" ]
                then echo -e "$entry"
                elif [ $exec_mode == "auto" ]
                then echo -e "$entry" >> $LOG
                fi

        return 0
        }

        log_entry "$report_type" "$report_code" "$report_message"

        found=0
        for code in "${restart_codes[@]}"
                do
                if [[ "$code" == "$report_code" ]]
                then
                        found=1
                        break
                fi
        done

        # Restart the server with the previously used PaperMC build if there has been an error contained in the array
        if [[ $found == 1 ]]
        then

                # If the previously used PaperMC build has been archived, move it back
                if [[ (! -f $papermc_path/paper-*-$current_build.jar) && (-f $ARCHIVE/paper-*-$current_build.jar) ]]
                then mv $ARCHIVE/paper-*-$current_build.jar $papermc_path
                fi

                server_starter "previous" $current_build
        fi

        # Exit the script only if the call was for an error
        if [[ $report_type == "ERROR" ]]
        then
                reporter "NOT" "$report_message"
                exit $report_code
        else return $report_code
        fi

return 0
}

# Verifies that the values specified for the path/session variables exist
check_input() {

    if [[ (! -f $1) && (! -d $1) && ($2 != "<tmuxsession>") ]]
    then handler "ERROR" 3 "The specified path for $2 does not exist."
    elif [[ $2 == "<tmuxsession>" ]]
    then
                tmux -S $tmux_session_path has-session -t $1 2> /dev/null

                if [ $? -ne 0 ]
                then handler "ERROR" 4 "The specified tmux session '"$1"' does not exist."
                fi

    fi

return 0
}

# Verifies that the required packages are present in the system
check_dependencies() {

local counter=0
local missing=()

        for i in "${dependencies[@]}"
        do
                command -v "$i" >/dev/null 2>&1 || {
                        ((counter++))
                        missing+=($i)
                }
        done

        if [[ $counter -gt 0 ]]
        then
                miss=$(echo ${missing[*]} | tr ' ' ',')
                handler "ERROR" 5 "Missing dependencies: $miss."
        fi

return 0
}

# Gets the current local PaperMC, Minecraft, and available PaperMC build numbers
get() {

        case $1 in
        mc_version)
                handler "INFO" 0 "Fetching current Minecraft version..."
                mc_version=$(curl -s "$PAPER_API_URL" | grep -Eo $MC_VERSION_REGEX | sort -r | head -1)
                ;;
        latest_build)
                handler "INFO" 0 "Fetching latest available PaperMC build..."
                latest_build=$(curl -s "$PAPER_API_URL/versions/$mc_version" | jq -r '.builds[]' | sort -rn | head -1)
                ;;
        current_version)
                handler "INFO" 0 "Checking currently used PaperMC version..."
                current_version=$(find $papermc_path -name "paper-*" -maxdepth 1 2> /dev/null | grep -Eo "$MC_VERSION_REGEX")
                ;;
        current_build)
                handler "INFO" 0 "Checking currently used PaperMC build..."
                current_build=$(find $papermc_path -name "paper-*" -maxdepth 1 2> /dev/null | grep -Eo "[0-9]\-$BUILD_NUMBER_REGEX\." | grep -Eo "$BUILD_NUMBER_REGEX\." | grep -Eo "$BUILD_NUMBER_REGEX")
                ;;
        build_channel)
                handler "INFO" 0 "Checking if the latest available build is production ready..."
                build_channel=$(curl -s "$PAPER_API_URL/versions/$mc_version/builds/$latest_build" | jq -r '.channel')
                ;;
        esac

        if [[ ($? != 0) || (-z "$$1") ]]
        then    

                # If the error comes from 'current_build', it does not stop the script to try to download it later on
                if [[ $1 == "current_build" ]]
                then handler "WARNING" 6 "Could not determine '$1'."  
                else handler "ERROR" 6 "Could not determine '$1'."
                fi
                
        fi

return 0
}

# Transform version syntax into integers of the same size: 1.20.6 -> 12006, 1.21 -> 12100
normalize_versions() {
        local whole_latest=$1
        local whole_current=$2
        local regex="^([0-9]+)\.([0-9]+)(\.([0-9]+))?$"

        normalize() {

                if [[ $1 =~ $regex ]]
                then
                        major=${BASH_REMATCH[1]}
                        rel=${BASH_REMATCH[2]}
                        ver=${BASH_REMATCH[4]:-0} 
                        printf "%d%02d%02d" $major $rel $ver
                fi

        return 0
        }

        current=$(normalize "$whole_current")
        latest=$(normalize "$whole_latest")

return 0
}

# Fetches the latest build and archives the previous one
download_latest_build() {
        handler "INFO" 0 "Downloading the latest PaperMC build..."

        wget -q $1 -P $papermc_path

        if [ $? -ne 0 ]
        then

                if [[ "$2" == "nd" ]]
                then handler "ERROR" 11 "The latest PaperMC build could not be downloaded AND there is no other version installed. Exiting."
                else handler "ERROR" 7 "The latest PaperMC build could not be downloaded."
                fi

        else

                if [[ "$2" == "nd" ]]
                then
                        handler "INFO" 0 "Saving newly downloaded build as current build since it could not be determined before."
                        current_build=$(find $papermc_path -name "paper-*" -maxdepth 1 2> /dev/null | grep -Eo "[0-9]\-$BUILD_NUMBER_REGEX\." | grep -Eo "$BUILD_NUMBER_REGEX\." | grep -Eo "$BUILD_NUMBER_REGEX")
                
                elif [ -n "$current_build" ]
                then
                        handler "INFO" 0 "Archiving previous build..."
                        mv $papermc_path/paper-*-$current_build.jar $ARCHIVE

                        if [ $? -eq 0 ]
                        then handler "INFO" 0 "Successfully moved the previous build to the archive."
                        else handler "WARNING" 13 "Could not move the previous build to the archive."
                        fi

                fi

        fi

return 0
}

# The build that was archived in the previous execution (if any) is deleted to not clutter the archive
unclutterer() {
        handler "INFO" 0 "Checking if there is any surplus on the archive..."

        local count=$(ls -l $ARCHIVE | grep "paper-*" | wc -l)

        if [ $count -gt 0 ]
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

# This function was written by Stefan Farestam, as seen in StackOverflow under the following link:
# https://stackoverflow.com/questions/5014632/how-can-i-parse-a-yaml-file-from-a-linux-shell-script/21189044#21189044
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# ######################### #
# Start of script execution #
# ######################### #

# Checks if the configuration file is available, the event isn't logged because without the configuration, no log file is defined
if [[ ! -f $CONF ]]
then    handler "ERROR" 1 "The configuration could not be found, this may be due to a wrongly defined path or to the file not existing. Please, provide a valid configuration path."    
else    eval $(parse_yaml $CONF)
fi

# Checks if every required variable from the configuration is set, that is, everything but the reporter's
if [[ -z "$papermc_path" || -z "$tmux_session_name" || -z "$tmux_session_path" ]]
then    handler "ERROR" 2 "One or more of the configuration variables are unset. Note that all required variables need to be set in order for the updater to work properly."
fi

handler "INFO" 0 "Starting the updater execution..."

dependencies=("curl" "jq" "tmux" "java" "wget")
check_dependencies

check_input $papermc_path "<papermc_path>"
check_input $tmux_session_name "<tmuxsession>"

get "mc_version"
get "latest_build"
get "current_version"
get "current_build"
get "build_channel"

normalize_versions $mc_version $current_version

# Despite being a constant, it can't be defined before giving meaning to "mc_version" and "latest_build"
LATEST_BUILD_LINK="$PAPER_API_URL/versions/$mc_version/builds/$latest_build/downloads/paper-$mc_version-$latest_build.jar"

# Creates the archive directory to store the previously used PaperMC build if it doesn't already exist
if [ ! -d $ARCHIVE ]
then
        handler "INFO" 0 "No archive directory found. Creating it..."

        mkdir $ARCHIVE

        if [ $? -ne 0 ]
        then handler "ERROR" 8 "Could not create the archives directory. It is necessary for archiving previously working .jars in a tidied manner."
        else handler "INFO" 0 "Created directory for archiving the latest working PaperMC .jar"
        fi

fi

if {
        # The version remains the same but there is a new build
        { [[ "$latest" -eq "$current" ]] && [[ "$latest_build" -gt "$current_build" ]]; } ||
        # Or there is a new version
        { [[ "$latest" -gt "$current" ]] &&
                # That either is stable or is experimental but has been allowed
                { [[ "$build_channel" == "default" ]] || [[ "$experimental_builds_enabled" == "yes" ]]; }
        }
        # Or there is no previous installation
        } || [[ -z "$current_build" ]]
then

        if [ -z "$current_build" ]
        then download_latest_build $LATEST_BUILD_LINK "nd"
        else
                if [[ "$build_channel" == "experimental" ]] && [[ "$experimental_builds_enabled" == "yes" ]]
                then handler "INFO" 0 "The update found is in an EXPERIMENTAL state."       
                fi

                download_latest_build $LATEST_BUILD_LINK

        fi

        if [ -n "$(pidof java)" ]
        then
                server_stopper

                # Uses `check` to check, since using `$?` could lead to false positives
                if [ -n "$(pidof java)" ]
                then handler "ERROR" 9 "The server failed to stop."
                fi

                echo "flag="1"" > $FLAGDIR

        else handler "WARNING" 12 "The PaperMC server was not running."
        fi

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

        else handler "ERROR" 12 "The latest PaperMC version could not be found on the system."
        fi

        handler "INFO" 0 "The PaperMC server has successfully been updated and restarted."
        reporter "OK" ", and the server has correctly been updated and restarted."
        echo "flag="0"" > $FLAGDIR
        unclutterer

        if [[ "$latest" -gt "$current" ]]
        then reporter "UPDATED"
        fi

elif [ "$build_channel" == "experimental" ] && [ "$experimental_builds_enabled" == "no" ]
then
        handler "INFO" 0 "There is a newer version; however, it's still an experimental build."
        reporter "OK" "; however, the update found is still in an experimental state."

else
        handler "INFO" 0 "There were no updates for the server."
        reporter "OK" "; however, there were no updates for the server."
fi