#!/bin/bash

#######################################################################################################################################################################
#######################################################################################################################################################################
#
# Script provided by DARE Technology Ltd to be used "as is".
# Copyright (c) 2023
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
# Parameter 4 - Application Name (Use the Installation Format from the DARE Update App Catalog - E.g. Google Chrome)
# Parameter 5 - Action (Options are "install" to have DARE Update install the App silently, "install-showProgress" to install with a progress prompt, "update" to mark an App for a forced update, or "selfService" when creating the Self Service Application Updates policy.)
# Parameter 6 - Grace Period in Minutes (Only applicable if specifying "update" as the action. This is the amount of time the user has to save and quit the App before it quits automatically. Leave blank for 15 minutes)
# Parameter 7- Deferrals Allowed (Only required if specifying "update" as the action. This is the amount of times a user can defer an update prompt before being forced to update. Leave blank for no deferrals and just a grace period timer)
# Paramter 8 - Minimum Deferral Window (Only applicable if specifying "update" as the action. This is the minimum time in minutes DARE Update will prompt users to update again after they defer. Leave blank for the the default value of 60 minutes)
#
#######################################################################################################################################################################
#######################################################################################################################################################################
#
# ABOUT THIS SCRIPT:
# This script will either initiate an App to be installed by DARE Update, or mark an app to be updated by DARE Update.
#
# REQUIREMENTS:
# 1. DARE Update must be installed.
# 2. Parameter 4 must be configured to define the Application in DARE Update format. This can be found on the online 
# 	 DARE Update catalog (www.dareupdate.co). The only scenario in which parameter 4 can be left blank is when
#	 using selfService as the action.
# 3. Parameter 5 must be configured to define the action. You must specify either Install to install an App, Update to
# 	 mark an App to be updated by DARE Update, or selfService to create the Self Service Application Updates policy.
#
# OPTIONAL:
# 1. Parameter 6 can be used to define a grace period when using the "update" action. This will be used in the prompt users
#	 see when the App is in use. At the end of the grace period the App quits automatically to update. If no grace period
#	 is defined, the default value of 15 minutes will be used.
# 2. Paramter 7 can be used to configure deferrals when using the "update" action. This will allow users to defer the forced
#	 update if the App is in use. By default forced update checks occur once every hour so this will be the deferral period
# 	 before being prompted again.
# 3. Paramter 8 can be used to configure a minimum deferral window in minutes when using the "update" action. If you allow
#    users to defer forced update prompts, by default they will be prompted again an hour later. If you find this too agressive,
#    specify a custom deferral window here. DARE Update will ensure then specified time window has elapsed before the user
#    is prompted to update again.
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
deferralPeriod="${8}"

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
minimumOSVersion="11"
macOSmajor=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1}')
receiptPath="/Library/Application Support/DARE/Run/Receipts"
targetApp=$(/bin/echo "$targetApp" | /usr/bin/sed 's/[\]//g')
patchReceipt="/Library/Application Support/DARE/Run/Receipts/${targetApp} Patch Receipt.plist"

######### Functions #########

installLogic() {
	
	IFS=$'\n\b'
	installResult=($(/usr/local/bin/dareupdate -i $targetApp))
	
	for line in ${installResult[@]}; do
		if [[ "$line" == *"was not found in the DARE Update App catalog."* ]]; then
			/bin/echo "Error: \"$targetApp\" was not found in the DARE Update App catalog"
			/bin/echo "Please specify a valid Application installation format. Installation formats can be found in the online App catalog: www.dareupdate.co"
			/bin/echo "For assistance, contact helpdesk@dare.tech"
			exit 1
		elif [[ "$line" == *"Error:"* ]]; then
			errorFixed=$(/bin/echo $line | /usr/bin/sed 's/Error: //g' )
			/bin/echo "Error: The $targetApp install encountered an error. For detailed information, please refer to /var/log/DAREUpdate.log"
			/bin/echo "Error returned: $errorFixed"
			/bin/echo "For assistance, contact helpdesk@dare.tech"
			exit 1
		elif [[ "$line" == *"install was successful"* ]]; then
			/bin/echo "The $targetApp install was successful"
			exit 0
		fi
	done
	
}

installProgressLogic() {
	
	IFS=$'\n\b'
	installResult=($(/usr/local/bin/dareupdate -ip $targetApp))
	
	for line in ${installResult[@]}; do
		if [[ "$line" == *"was not found in the DARE Update App catalog."* ]]; then
			/bin/echo "Error: \"$targetApp\" was not found in the DARE Update App catalog"
			/bin/echo "Please specify a valid Application installation format. Installation formats can be found in the online App catalog: www.dareupdate.co"
			/bin/echo "For assistance, contact helpdesk@dare.tech"
			exit 1
		elif [[ "$line" == *"Error:"* ]]; then
			errorFixed=$(/bin/echo $line | /usr/bin/sed 's/Error: //g' )
			/bin/echo "Error: The $targetApp install encountered an error. For detailed information, please refer to /var/log/DAREUpdate.log"
			/bin/echo "Error returned: $errorFixed"
			/bin/echo "For assistance, contact helpdesk@dare.tech"
			exit 1
		elif [[ "$line" == *"install was successful"* ]]; then
			/bin/echo "The $targetApp install was successful"
			exit 0
		fi
	done
	
}

updateLogic() {
	
	IFS=$'\n\b'
	numberRegex='^[0-9]+$'
	validateAppFormat=($(/usr/local/bin/dareupdate -c $targetApp))
	
	for line in ${validateAppFormat[@]}; do
		if [[ "$line" == *"was not found in the DARE Update App catalog"* ]]; then
			/bin/echo "Error: Could not mark \"$targetApp\" to be updated because it was not found in the DARE Update App catalog. For valid App format names, see www.dareupdate.co"
			/bin/echo "For assistance, contact helpdesk@dare.tech"
			exit 1
		fi
	done
	
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
	else
		if [[ ! "$gracePeriodMinutes" =~ $numberRegex ]]; then
			/bin/echo "Error: The specified grace period value was not in number format. The default value of 15 minutes will be used."
			gracePeriodMinutes="15"
		fi
	fi
	
	/usr/bin/defaults write "$patchReceipt" "gracePeriod" "$gracePeriodMinutes"
	
	if [[ -z "$deferralPeriod" ]]; then
		deferralPeriod="59"
	else
		if [[ ! "$deferralPeriod" =~ $numberRegex ]]; then
			/bin/echo "Error: The specified deferral period value was not in number format. The default value of 60 minutes will be used."
			deferralPeriod="59"
		fi
	fi
	
	/usr/bin/defaults write "$patchReceipt" "deferralPeriod" -integer $deferralPeriod
	/usr/bin/defaults write "$patchReceipt" "lastRun" -integer 0
	
	if [[ -z "$deferralsAllowed" ]] || [[ "$deferralsAllowed" == "0" ]]; then
		/usr/bin/defaults write "$patchReceipt" "deferrals" "N/A"
	else
		if [[ "$deferralsAllowed" =~ $numberRegex ]]; then
			/usr/bin/defaults write "$patchReceipt" "deferrals" "${deferralsAllowed}"
		else
			/bin/echo "Error: The specified deferrals value was not in number format. Please specify using a number and try again."
			exit 1
		fi
	fi
	
	/bin/echo "$targetApp was marked for a forced update"
	/bin/echo "Exiting..."
	
	exit 0
	
}

selfServiceLogic() {
	
	IFS=$'\n\b'
	selfServiceResult=($(/usr/local/bin/dareupdate -u selfService))
	
	for line in ${selfServiceResult[@]}; do
		if [[ "$line" == *"Error: Unable to connect to the DARE Update bucket - HTTP result 403: forbidden"* ]]; then
			/bin/echo "Error: Could not perform a Self Service update check because the computer could not connect to the DARE Update cloud bucket."
			/bin/echo "Ensure that a valid access and secret key is defined in the license configuration, and ensure the time and date is correct on this computer"
			/bin/echo "For assistance, contact helpdesk@dare.tech"
			exit 1
		elif [[ "$line" == *"Error:"* ]]; then
			errorFixed=$(/bin/echo $line | /usr/bin/sed 's/Error: //g' )
			/bin/echo "Error: The Self Service update attempt encountered an error. For detailed information, please refer to /var/log/DAREUpdate.log"
			/bin/echo "Error returned: $errorFixed"
			/bin/echo "For assistance, contact helpdesk@dare.tech"
			exit 1
		elif [[ "$line" != *"Error:"* ]]; then
			/bin/echo "The Self Service update run encountered no errors"
			exit 0
		fi
	done
	
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

# Check a target App was specified
if [[ -z "$targetApp" ]]; then
	if [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') != "selfservice" ]]; then
		/bin/echo "Error: No Application was specified. Please specify an Application from the DARE Update App Catalog and try again."
		/bin/echo "For assistance, please contact helpdesk@dare.tech"
		exit 1
	fi
fi

# Check an action was specified
if [[ -z "$action" ]]; then
	/bin/echo "Error: No action was specified. Specify either \"Install\" to install an App, \"Update\" to mark an App for an urgent update, or \"selfService\" to create a Self Service Application Updates policy."
	exit 1
fi

# Determine whether an install or update was specified and run the required logic
if [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') == "install" ]]; then
	/bin/echo "Initialising ${targetApp} install..."
	installLogic
elif [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') == "install-showprogress" ]]; then
	/bin/echo "Initialising ${targetApp} install..."
	installProgressLogic
elif [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') == "update" ]]; then
	/bin/echo "Marking ${targetApp} to be updated..."
	updateLogic
elif [[ $(/bin/echo "$action" | /usr/bin/awk '{print tolower($0)}') == "selfservice" ]]; then
	selfServiceLogic
else
	/bin/echo "Error: Invalid action parameter value passed."
	/bin/echo "Possible values are \"Install\" to install an App, \"Update\" to mark an App for an urgent update, or \"selfService\" to create a Self Service Application Updates policy."
	/bin/echo "For assistance, please contact helpdesk@dare.tech"
	exit 1
fi