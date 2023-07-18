#!/bin/bash

################################################################################################################################
################################################################################################################################
#
# Script provided by DARE Technology Ltd to be used "as is".
# Copyright (c) 2023
# Support - www.dare.tech
#
# Note: Modifications to this script (other than modifying parameters and modifications made by DARE) do not fall into
#    	the scope of support requests relating to this workflow.
#
################################################################################################################################
################################################################################################################################
#
# Parameter labels:
#
# Parameter 4 - Jamf Pro URL
# Parameter 5 - API Username
# Parameter 6 - API Password
#
################################################################################################################################
################################################################################################################################
#
# ABOUT THIS SCRIPT:
# This script collects the main DARE Update log located at /var/log/DAREUpdate.log, as well as the update framework logs located
# at /Library/Application Support/DARE/Logs. The resulting .zip file is uploaded to the attachment payload within the computer
# inventory record.
#
# REQUIREMENTS:
# 1. DARE Update must be installed on the client
# 2. The Jamf Pro server must be defined in parameter 4
# 3. The API username must be defined in parameter 5
# 4. The API password must be defined in parameter 6
#
################################################################################################################################
################################################################################################################################

### Variables
jamfProURL="${4}"
apiUser="${5}"
apiPass="${6}"
serialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/grep Serial | /usr/bin/awk '{print $NF}' )
timeStamp=$(/bin/date '+%Y-%m-%d-%H-%M-%S' )
logDir="/private/tmp/DAREUpdateLogs-$timeStamp"
osMajor=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1}')
osMinor=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $2}')

## Copy the log files and compress to .zip
/bin/mkdir "$logDir"
/bin/mkdir "$logDir/UpdateFramework"
if [[ -e /var/log/DAREUpdate.log ]];then
	/bin/cp /var/log/DAREUpdate.log "$logDir"
else
	/bin/echo "Error: DARE Update log not found"
	exit 1
fi
if [[ -d /Library/Application\ Support/DARE/Logs ]]; then
	/bin/cp -R /Library/Application\ Support/DARE/Logs "$logDir/UpdateFramework"
else
	/bin/echo "Warning: Update framework log not found. Only the DARE Update log will be uploaded."
fi
fileName="DAREUpdate-Logs-$timeStamp.zip"
/usr/bin/zip -r /private/tmp/$fileName "$logDir"

## Get computer ID
if [[ "$osMajor" -ge 11 ]]; then
	jamfProID=$(/usr/bin/curl -k -u "$apiUser":"$apiPass" $jamfProURL/JSSResource/computers/serialnumber/$serialNumber/subset/general | xpath -e "//computer/general/id/text()")
elif [[ "$osMajor" -eq 10 && "$osMinor" -gt 12 ]]; then
    jamfProID=$(/usr/bin/curl -k -u "$apiUser":"$apiPass" $jamfProURL/JSSResource/computers/serialnumber/$serialNumber/subset/general | xpath "//computer/general/id/text()")
fi

## Upload DARE Update logs
/usr/bin/curl -k -u "$apiUser":"$apiPass" $jamfProURL/JSSResource/fileuploads/computers/id/$jamfProID -F name=@/private/tmp/$fileName -X POST

## Cleanup
/bin/rm /private/tmp/$fileName
/bin/rm -rf "$logDir"

exit 0