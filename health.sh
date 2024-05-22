#! /bin/bash

# This script checks wether the Java server is running to notify in the event of a failure
ADMIN="<Admin's UID to mention>"
WH_URL="<Discord's WebHook URL"

send_notification() {
  
  # Construct payload
  local payload=$(cat <<EOF
{
  "content": "CraftCeres se ha caído, @everyone.\nCambiad el nombre del canal mientras se restaura."
}
EOF
)
    curl -H "Content-Type: application/json" -X POST -d "$payload" $WH_URL
}

if [ -z "$(pidof java)" ]
    then send_notification   
fi