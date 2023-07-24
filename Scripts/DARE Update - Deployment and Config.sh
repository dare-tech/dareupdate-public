#!/bin/bash

###########################################################################################################################################################################################################
###########################################################################################################################################################################################################
#
# Script provided by DARE Technology Ltd to be used "as is".
# Copyright (c) 2023
# Support - www.dare.tech
#
# Note: Modifications to this script (other than modifying parameters and modifications made by DARE) do not fall into
#    	the scope of support requests relating to this workflow.
#
###########################################################################################################################################################################################################
###########################################################################################################################################################################################################
#
# Parameter labels:
#
# Parameter 4 - Specify your DARE Update Access Key here to ensure that if the license configuration profile fails to install, you can still access the cloud bucket (Optional, recommended)
# Parameter 5 - Specify your DARE Update Secret Key here to ensure that if the license configuration profile fails to install, you can still access the cloud bucket (Optional, recommended)
# Parameter 6 - Custom recurring DARE Update run interval. The default value when no custom value is defined is 15 minutes (Optional: Do not modify unless necessary)
# Parameter 7 - Leave this value blank to download and install the latest version of DARE Update, or specify 0 if you wish to install a specific DARE Update version separately
# Parameter 8 - Leave this value blank to verify the signing information for the DARE Update installer, or specify 0 if you wish to disable signing verification for the installer (not recommended)
#
###########################################################################################################################################################################################################
###########################################################################################################################################################################################################
#
# ABOUT THIS SCRIPT
# This script downloads and installs the latest version of DARE Update (if configured) and allows you to write your DARE Update access keys locally incase the license configuration profile fails to
# install. You can also modify how often the DARE Update daemon initiates the run mechanism if required (not recommended)
#
###########################################################################################################################################################################################################
###########################################################################################################################################################################################################

################################### VARIABLES ###################################

macOSmajor=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1}')
accessKey="${4}"
secretKey="${5}"
runIntervalMinutes="${6}"
installLatestVersion="${7}"
verifyDeveloperSignature="${8}"
runDaemon="/Library/LaunchDaemons/com.dare.update.run.plist"
runDaemonLabel="com.dare.update.run"
latestInstaller="https://s3.eu-west-1.wasabisys.com/latestinstaller/DAREUpdateInstaller-Latest.pkg"
downloadPath="/private/tmp/DAREUpdateInstaller-Latest.pkg"
developerID="DARE TECHNOLOGY LIMITED (JTYACQP7Y5)"
targetMount=$1
if [ -z "$targetMount" ]; then 
	targetMount="/"
fi

#################################### Install Functions ####################################

function verifyDeveloper() {
	
	/bin/echo "Verifying signing information..."
	IFS=$'\n\b'
	signingInfo=($(/usr/sbin/pkgutil --check-signature $downloadPath))
	for line in ${signingInfo[@]} ; do
		if [[ "$line" == *"Developer ID Installer:"* ]]; then
			pkgDeveloperID=$(/bin/echo "$line" | /usr/bin/awk -F 'Developer ID Installer: ' '{print $NF}')
			if [[ "$pkgDeveloperID" == "$developerID" ]]; then
				/bin/echo "The installer PKG is signed with the expected developer information"
			else
				/bin/echo "Error: The installer PKG is not signed with the expected developer information. Please deploy the latest installer manually"
				/bin/echo "Expected Developer ID: $developerID"
				/bin/echo "Downloaded PKG Developer ID: $pkgDeveloperID"
				/bin/echo "Removing the downloaded PKG..."
				/bin/rm "$downloadPath"
				/bin/echo "Exiting..."
				exit 1
			fi
		elif [[ "$line" == *"Status: no signature"* ]]; then
			/bin/echo "Error: The installer PKG is not signed with the expected developer information. Please deploy the latest installer manually"
			/bin/echo "Expected Developer ID: $developerID"
			/bin/echo "Downloaded PKG Developer ID: PKG is unsigned"
			/bin/echo "Removing the downloaded PKG..."
			/bin/rm "$downloadPath"
			/bin/echo "Exiting..."
			exit 1
		fi
	done
	
}

function installLatest() {
	
	if [[ -e "$downloadPath" ]]; then
		/bin/rm "$downloadPath"
	fi
	
	/bin/echo "Downloading DARE Update installer..."
	/usr/bin/curl "$latestInstaller" --output "$downloadPath" > /dev/null
	/bin/sleep 2
	
	if [[ -e "$downloadPath" ]]; then
		/bin/echo "Download complete."
		if [[ "$verifyDeveloperSignature" != "0" ]]; then
			verifyDeveloper
		else
			/bin/echo "Skipping signature verification"
		fi
		/bin/echo "Installing DARE Update..."
		/usr/sbin/installer -pkg "$downloadPath" -target "$targetMount"
		/bin/sleep 2
		if [[ ! -e /Library/Application\ Support/DARE/Bin/dareupdate ]]; then
			if [[ -e "$downloadPath" ]]; then
				/bin/rm "$downloadPath"
			fi
			/bin/echo "Error: DARE Update was not found after the install attempt. Please install DARE Update manually."
			exit 1
		else 
			if [[ -e "$downloadPath" ]]; then
				/bin/rm "$downloadPath"
			fi
			/bin/echo "The DARE Update install was successful."
			exit 0
		fi
	else
		if [[ -e "$downloadPath" ]]; then
			/bin/rm "$downloadPath"
		fi
		/bin/echo "Error: The DARE Update installer could not be downloaded. Please install DARE Update manually."
		exit 1
	fi
	
}

#################################### LOGIC ####################################

# Check that the computer is running at least macOS Big Sur
if [[ "$macOSmajor" -lt 11 ]]; then
	/bin/echo "Error: This computer is running prior to macOS 11. DARE Update is supported with macOS 11 Big Sur onwards, please upgrade macOS on this computer and reinstall the latest version of DARE Update"
	exit 1
fi

# Download and install the latest version of DARE Update if required
if [[ -n "$installLatestVersion" ]]; then
	if [[ "$installLatestVersion" == "0" ]]; then
		/bin/echo "The latest version installer option was disabled. Skipping download and install..."
	elif [[ "$installLatestVersion" == "1" ]]; then
		installLatest
	else
		/bin/echo "Error: Invalid flag specified in the install latest version perameter."
		installLatest
	fi
else
	installLatest
fi


# If a custom run interval was defined, recreate the run daemon with the custom interval
if [[ -n "$runIntervalMinutes" ]]; then
	# Remove the daemon if it already exists
	if [[ -e "$runDaemon" ]]; then
		/bin/launchctl bootout system "$runDaemon"
	fi
	/bin/rm -rf "$runDaemon"
	# Create the scheduled update daemon
	/usr/bin/defaults write $runDaemon Label -string "$runDaemonLabel"
	/usr/bin/defaults write $runDaemon ProgramArguments -array -string "/usr/local/bin/dareupdate" -string "-u" -string "run"
	/usr/bin/defaults write $runDaemon RunAtLoad -boolean false
	/usr/bin/defaults write $runDaemon StartInterval -int "${runInterval}"
	/bin/sleep 5
	# Fix the permissions on the scheduled update daemon
	/usr/sbin/chown root:wheel $runDaemon
	/bin/chmod 644 $runDaemon
	## Load the scheduled update daemon
	/bin/launchctl bootstrap system "$runDaemon"
fi

# Write Update Framework preferences locally incase the license configuration profile fails to install
/usr/bin/defaults write /Library/Preferences/ManagedInstalls SoftwareRepoURL "https://dareupdate.s3.eu-west-1.wasabisys.com/munki_repo"
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist SoftwareRepoURL "https://dareupdate.s3.eu-west-1.wasabisys.com/munki_repo"
if [[ -n "$accessKey" ]]; then
	/usr/bin/defaults write /Library/Preferences/ManagedInstalls AccessKey "$accessKey"
	/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist AccessKey "$accessKey"
else
	/bin/echo "No access key was defined. Skipping writing to local preferences."
fi
if [[ -n "$secretKey" ]]; then
	/usr/bin/defaults write /Library/Preferences/ManagedInstalls SecretKey "$secretKey"
	/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist SecretKey "$secretKey"
else
	/bin/echo "No secret key was defined. Skipping writing to local preferences."
fi
/usr/bin/defaults write /Library/Preferences/ManagedInstalls Region "eu-west-1"
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist Region "eu-west-1"
/usr/bin/defaults write /Library/Preferences/ManagedInstalls AggressiveUpdateNotificationDays 0
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist AggressiveUpdateNotificationDays 0
/usr/bin/defaults write /Library/Preferences/ManagedInstalls UserNotificationCenterDays -1
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist UserNotificationCenterDays -1
/usr/bin/defaults write /Library/Preferences/ManagedInstalls SuppressUserNotification true
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist SuppressUserNotification true
/usr/bin/defaults write /Library/Preferences/ManagedInstalls SuppressStopButtonOnInstall -bool true
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist SuppressStopButtonOnInstall -bool true
/usr/bin/defaults write /Library/Preferences/ManagedInstalls LogFile "/Library/Application Support/DARE/Logs/UpdateFramework.log"
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist LogFile "/Library/Application Support/DARE/Logs/UpdateFramework.log"
/usr/bin/defaults write /Library/Preferences/ManagedInstalls ManagedInstallDir "/Library/Application Support/DARE/Managed Installs"
/usr/bin/defaults write /private/var/root/Library/Preferences/ManagedInstalls.plist ManagedInstallDir "/Library/Application Support/DARE/Managed Installs"

exit 0