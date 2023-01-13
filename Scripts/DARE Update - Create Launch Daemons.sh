#!/bin/bash

###########################################################################################################################################################################################################
###########################################################################################################################################################################################################
#
# Script provided by DARE Technology Ltd to be used "as is".
# Copyright (c) 2022
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
# Parameter 4 - Recurring cached update check interval in minutes. The default if no custom value is defined is 180 minutes
# Parameter 5 - Recurring forced update check interval in minutes. The default if no custom value is defined is 60 minutes
#
###########################################################################################################################################################################################################
###########################################################################################################################################################################################################
#
# ABOUT THIS SCRIPT
# This script creates the launch daemons which are responsible for initialising the regular cached and forced update checks.
# Use parameter 4 to define a custom interval in minutes for the recurring cached update checks. The default if no custom value is defined is 180 minutes.
# Use parameter 5 to define a custom interval for the recurring forced update checks. The default if no custom value is defined is 60 minutes.
#
###########################################################################################################################################################################################################
###########################################################################################################################################################################################################

################################### VARIABLES ###################################

macOSmajor=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1}')

# Scheduled update daemon variables
scheduledCheckIntervalMinutes="${4}"
if [[ -z ${scheduledCheckIntervalMinutes} ]]; then
	scheduledCheckIntervalMinutes="180"
fi
scheduledCheckInterval=$((scheduledCheckIntervalMinutes * 60))
scheduledLaunchDaemon="/Library/LaunchDaemons/com.dare.update.notifications.plist"
scheduledDaemonLabel="com.dare.update.notifications"
# Forced update daemon variables
forcedCheckIntervalMinutes="${5}"
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

exit 0