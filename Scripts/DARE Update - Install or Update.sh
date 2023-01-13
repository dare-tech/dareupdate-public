#!/bin/bash

#######################################################################################################################################################################
#######################################################################################################################################################################
#
# Script provided by DARE Technology Ltd to be used "as is".
# Copyright (c) 2022
# Support - www.dare.tech
#
# Note: Modifications to this script (other than modifying parameters and modifications made by DARE) do not fall into
#    	the scope of support requests relating to this workflow.
#
#######################################################################################################################################################################
#######################################################################################################################################################################
#
# Parameter labels:
#
# Parameter 4 - Application Name (Use the format from the DARE Update App catalog (www.dare.tech/applications) - E.g. Google Chrome)
# Parameter 5 - Action (Options are "install" to have DARE Update install the App, "update" to have DARE Update attempt to force the App to update or "selfService" when creating the Self Service Application Updates policy.)
# Parameter 6 - Grace Period in Minutes (Only required if specifying "update" as the action. This is the amount of time the user has to save and quit the App before it quits automatically. Leave blank for 15 minutes)
# Parameter 7- Deferrals Allowed (Only required if specifying "update" as the action. This is the amount of times a user can defer an update prompt before being forced to update. Leave blank for no deferrals and just the grace period timer)
#
#######################################################################################################################################################################
#######################################################################################################################################################################
#
# ABOUT THIS SCRIPT:
# This script will either initiate an App to be installed by DARE Update, or mark an app to be updated by DARE Update.
#
# REQUIREMENTS:
# 1. DARE Update must be installed and active.
# 2. If updating, the target version of the App must be avilable in DARE Update. We aim to release critical updates in a 
#	 timely mannor, but updates must pass a series of security checks before being released to the live environment.
#    You can check with our team that the update has been released by emailing helpdesk@dare.tech.
# 3. Parameter 4 must be configured to define the Application in DARE Update format. This can be found on the online 
# 	 DARE Update catalog (www.dare.tech/applications). The only scenario in which parameter 4 can be left blank is when
#	 using selfService as the action.
#
#	 Parameter 5 must be configured to define the action. You must specify either Install to install an App, Update to
# 	 mark an App to be updated by DARE Update or selfService to create the Self Service Application Updates policy.
#
#    Parameter 6 can be used to define a grace period when using the "update" action. This will be used in the prompt users
#	 see when the App is in use. At the end of the grace period the App quits automatically to update. If no grace period
#	 is defined the default is 15 minutes.
#
#	 Paramter 7 can be used to configure deferrals when using the "update" action. This will allow users to defer the forced
#	 update if the App is in use. By default forced update checks occur once every hour so this will be the deferral period
# 	 before being prompted again.
#
#######################################################################################################################################################################
#######################################################################################################################################################################

######### Configurable Variables #########

# Required
targetApp="${4}" # Not required if using selfService as the action
action="${5}"
# Optional - Custom grace periods and deferrals can be configured for forced updates if required. The default grace period is 15 minutes.
gracePeriodMinutes="${6}"
deferralsAllowed="${7}"


######################################### DO NOT MODIFY THE CODE UNDER THIS LINE #########################################
##########################################################################################################################
##########################################################################################################################
##########################################################################################################################
##########################################################################################################################
##########################################################################################################################
##########################################################################################################################
##########################################################################################################################
##########################################################################################################################


######### Fixed Variables #########

bearerToken="sThgqPTMAWzRXr3YPh1NhEJkpe0qfldM"
appData=$(/usr/bin/curl -s -X GET -H "Authorization: Bearer $bearerToken" 'https://api.dare.tech/items/Applications/?export=xml&limit=-1')
apiCheck=$(/usr/bin/curl -s -o /dev/null -L -w ''%{http_code}'' https://api.dare.tech/items/Applications/?export=xml&limit=-1)
minimumOSVersion="11"
macOSmajor=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1}')
dialogBinary="/usr/local/bin/dialog"
receiptPath="/Library/Application Support/DARE/Run/Receipts"
targetApp=$(/bin/echo "$targetApp" | /usr/bin/sed 's/[\]//g')
patchReceipt="/Library/Application Support/DARE/Run/Receipts/${targetApp} Patch Receipt.plist"
appFormatCheck=$(/bin/echo "$appData" | /usr/bin/grep "<DARE_Update_Name>${targetApp}</DARE_Update_Name>" | /usr/bin/awk -F '>|<' '/<DARE_Update_Name>/{print $3}')


######### Functions #########


installLogic() {
	
	/usr/local/bin/dareupdate -i "${targetApp}"
	exit 0
	
}

updateLogic() {
	
	# Check if the Dialog binary is installed
	if [[ ! -e "$dialogBinary" ]]; then
		/bin/echo "Error: DARE Update is installed but the Dialog binary was not found. Please update the computer to at least version 5.7.0 of DARE Update first, then run this policy again."
		exit 1
	fi
	
	# If the receipt path doesn't exist create it
	if [[ ! -e "$receiptPath" ]]; then
		/bin/echo "The receipt file directory doesn't exist, creating it..."
		/bin/mkdir "$receiptPath"
		/bin/chmod 644 "$receiptPath"
		/usr/sbin/chown root:wheel "$receiptPath"
	fi
	
	if [[ -e "$patchReceipt" ]]; then
		/bin/rm -rf "$patchReceipt"
	fi
	
	if [[ -z "$gracePeriodMinutes" ]]; then
		gracePeriodMinutes="15"
	fi
		
	/usr/bin/defaults write "$patchReceipt" "gracePeriod" "$gracePeriodMinutes"
	
	if [[ -z "$deferralsAllowed" ]] || [[ "$deferralsAllowed" == "0" ]]; then
		/usr/bin/defaults write "$patchReceipt" "deferrals" "N/A"
	else
		numberRegex='^[0-9]+$'
		if [[ "$deferralsAllowed" =~ $numberRegex ]]; then
			/usr/bin/defaults write "$patchReceipt" "deferrals" "${deferralsAllowed}"
		else
			/bin/echo "Error: The specified deferrals value was not in number format. Please specify using a number and try again."
			exit 1
		fi
	fi
	
	exit 0
	
}

selfServiceLogic() {
	
	/usr/local/bin/dareupdate -u selfService
	exit 0
	
}


######### Run Logic #########

# Check we're running as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	/bin/echo "Error: This script needs to be run as root."
	exit 1
fi

# Check DARE Update is installed
if [[ ! -e /usr/local/bin/dareupdate || ! -e /usr/local/munki/managedsoftwareupdate ]]; then
	/bin/echo "Error: DARE Update is not installed. Please run again after installing DARE Update."
	exit 1
fi

# Check the OS version, exit if running an unsupported OS Version
if [[ "$macOSmajor" -lt "$minimumOSVersion" ]]; then
	/bin/echo "Error: This device is running macOS ${macOSmajor}. The minimum macOS requirement for this workflow is macOS ${minimumOSVersion}"
	exit 1
fi

# Check that the DARE Update API is reachable
if [[ "$apiCheck" != "200" ]]; then
	/bin/echo "Error: The DARE Update API is not reachable. Please contact helpdesk@dare.tech for support."
	exit 1
fi

# Check a target App was specified.
if [[ -z "$targetApp" ]]; then
	if [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') != "selfservice" ]]; then
		/bin/echo "Error: No Application was specified. Please specify an Application from the provided DARE Update App list and try again."
		/bin/echo "For assistance, please contact helpdesk@dare.tech"
		exit 1
	fi
fi

# Check that the specified App was the correct DARE Update format.
if [[ -z "$appFormatCheck" && $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') != "selfservice" ]]; then
	/bin/echo "Error: The specified Application is not the correct format. Please specify an Application from the provided DARE Update App list and try again."
	/bin/echo "For assistance, please contact helpdesk@dare.tech"
	exit 1
fi

# Check an action was specified
if [[ -z "$action" ]]; then
	/bin/echo "Error: No action was specified. Specify either 'Install' to install an App, or 'Update' to force update an App."
	exit 1
fi

# Determine whether an install or update was specified and run the required logic.
if [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') == "install" ]]; then
	/bin/echo "Initialising ${targetApp} install..."
	installLogic
elif [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') == "update" ]]; then
	/bin/echo "Marking ${targetApp} to be updated..."
	updateLogic
elif [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') == "selfservice" ]]; then
	selfServiceLogic
else
	/bin/echo "Error: Invalid action parameter value passed."
	/bin/echo "Possible values are 'Install' to install an App or 'Update' to force update an App, or 'selfService' to create a Self Service Application Updates policy."
	exit 1
fi