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
# Parameter 6 - Custom recurring cached update check interval in minutes. The default if no custom value is defined is 15 minutes (Optional: Do not modify unless necessary)
# Parameter 7 - Custom recurring forced update check interval in minutes. The default if no custom value is defined is 60 minutes (Optional: Do not modify unless necessary)
#
###########################################################################################################################################################################################################
###########################################################################################################################################################################################################
#
# ABOUT THIS SCRIPT
# This script creates the launch daemons which are responsible for initialising the regular cached and forced update checks. It also writes the update framework information locally as a backup for cases
# where the license configuration profile fails to install
#
###########################################################################################################################################################################################################
###########################################################################################################################################################################################################

################################### VARIABLES ###################################

macOSmajor=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1}')
accessKey="${4}"
secretKey="${5}"

# Scheduled update daemon variables
scheduledCheckIntervalMinutes="${6}"
if [[ -z ${scheduledCheckIntervalMinutes} ]]; then
	scheduledCheckIntervalMinutes="15"
fi
scheduledCheckInterval=$((scheduledCheckIntervalMinutes * 60))
scheduledLaunchDaemon="/Library/LaunchDaemons/com.dare.update.notifications.plist"
scheduledDaemonLabel="com.dare.update.notifications"
# Forced update daemon variables
forcedCheckIntervalMinutes="${7}"
if [[ -z ${forcedCheckIntervalMinutes} ]]; then
	forcedCheckIntervalMinutes="60"
fi
forcedCheckInterval=$((forcedCheckIntervalMinutes * 60))
forcedLaunchDaemon="/Library/LaunchDaemons/com.dare.update.forcepatch.plist"
forcedDaemonLabel="com.dare.update.forcepatch"


#################################### LOGIC ####################################

# Check that the computer is running at least macOS Big Sur
if [[ "$macOSmajor" -lt 11 ]]; then
	/bin/echo "Error: This computer is running prior to macOS 11. DARE Update is supported with macOS 11 Big Sur onwards, please upgrade macOS on this computer and reinstall the latest version of DARE Update"
	exit 1
fi

# Remove the daemons if they already exist
if [[ -e "$scheduledLaunchDaemon" ]]; then
	/bin/launchctl bootout system "$scheduledLaunchDaemon"
fi
if [[ -e "$forcedLaunchDaemon" ]]; then
	/bin/launchctl bootout system "$forcedLaunchDaemon"
fi

/bin/rm -rf "$scheduledLaunchDaemon"
/bin/rm -rf "$forcedLaunchDaemon"

# Create the scheduled update daemon
/usr/bin/defaults write $scheduledLaunchDaemon Label -string "$scheduledDaemonLabel"
/usr/bin/defaults write $scheduledLaunchDaemon ProgramArguments -array -string "/usr/local/bin/dareupdate" -string "-u" -string "prompt"
/usr/bin/defaults write $scheduledLaunchDaemon RunAtLoad -boolean true
/usr/bin/defaults write $scheduledLaunchDaemon StartInterval -int "${scheduledCheckInterval}"
/bin/sleep 5

# Fix the permissions on the scheduled update daemon
/usr/sbin/chown root:wheel $scheduledLaunchDaemon
/bin/chmod 644 $scheduledLaunchDaemon

## Load the scheduled update daemon
/bin/launchctl bootstrap system "$scheduledLaunchDaemon"

# Create the forced update daemon
/usr/bin/defaults write $forcedLaunchDaemon Label -string "$forcedDaemonLabel"
/usr/bin/defaults write $forcedLaunchDaemon ProgramArguments -array -string "/usr/local/bin/dareupdate" -string "-u" -string "force"
/usr/bin/defaults write $forcedLaunchDaemon RunAtLoad -boolean false
/usr/bin/defaults write $forcedLaunchDaemon StartInterval -int "${forcedCheckInterval}"
/bin/sleep 5

# Fix the permissions on the forced update daemon
/usr/sbin/chown root:wheel $forcedLaunchDaemon
/bin/chmod 644 $forcedLaunchDaemon

## Load the forced update daemon
/bin/launchctl bootstrap system "$forcedLaunchDaemon"

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