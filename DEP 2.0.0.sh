#!/bin/bash

##################################################
# ABOUT: Provisioning Script
# DESCRIPTION: Functions and Calls to
#			   provision devices
# NOTES: Created by Mac Core Team
##################################################

while true;	do
	myUser=`whoami`
	dockcheck=`ps -ef | grep [/]System/Library/CoreServices/Dock.app/Contents/MacOS/Dock`
	echo "Waiting for file as: ${myUser}"
	sudo echo "Waiting for file as: ${myUser}" >> /var/log/jamf.log
	echo "regenerating dockcheck as ${dockcheck}."

	if [ ! -z "${dockcheck}" ]; then
		echo "Dockcheck is ${dockcheck}, breaking."
		break
	fi
	sleep 1
done

# Global variables
LoggedInUser=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RealName:0" /dev/stdin <<< "$(dscl -plist . -read /Users/$(stat -f%Su /dev/console) RealName)")

function LockScreen() {
	"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
	-windowType "fs" \
	-heading "Congratulations ${LoggedInUser}" \
	-description "Your Mac is being customized. This may take up to 30 minutes, depending on your network speed. Please call 1-800-527-4740 if you need any assistance." \
	-icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbook-retina-space-gray.icns \
	-iconSize "256" \
	-alignDescription "center" \
	-alignHeading "center" &

	sudo /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/MacOS/LockScreen -session 256
}

function ProvisionEA() {

	sudo mkdir /usr/local/ti
	sudo chmod 777 /usr/local/ti
	sudo /usr/libexec/PlistBuddy -c "add :Status string Not Provisioned" -c "add :ProvisioningScript string 0.0.0" /usr/local/ti/com.ti.provisioned.plist &&

	$(LockScreen)

	# Grant System Pane Preferences permissions
	sudo /usr/bin/security authorizationdb write system.preferences allow

	# Grant Printing Pane permissions
	sudo /usr/bin/security authorizationdb write system.preferences.printing allow
	sudo /usr/bin/security authorizationdb write system.print.operator allow
	sudo /usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group lpadmin
	sudo /usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group _lpadmin

	# Grant Network Pane permissions
	sudo /usr/bin/security authorizationdb write system.preferences.network allow
	sudo /usr/bin/security authorizationdb write system.services.systemconfiguration.network allow
}

function SetProvision() {
	sudo /usr/libexec/PlistBuddy -c "Set :ProvisioningScript 2.0.0" -c "Set :Status Provisioned" /usr/local/ti/com.ti.provisioned.plist
}

function CompName() {
	CompType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Name")
	SerialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	if [[ "${CompType}" == *"MacBook"* ]]; then
		ComputerName="L${SerialNumber}"
	else
		ComputerName="D${SerialNumber}"
	fi
	/usr/sbin/scutil --set ComputerName  "${ComputerName}"
	/usr/sbin/scutil --set LocalHostName "${ComputerName}"
	/usr/sbin/scutil --set HostName "${ComputerName}"
	/usr/bin/defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName "${ComputerName}"

}

JSSAPIpass="${4}"

function APICall() {
	jssURL="https://jssdmz.ext.ti.com:8443/JSSResource"
	serial=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	jssAPIUser="jssapi"
	jssAPIPass="${JSSAPIpass}"

	curl -X PUT -H "Accept: application/xml" -H "Content-type: application/xml" -k -u "${jssAPIUser}:${jssAPIPass}" -d "<computer><extension_attributes><attribute><name>${1}</name><value>${2}</value></attribute></extension_attributes></computer>" "${jssURL}"/computers/serialnumber/"${serial}"
}

function Recon() {
	sudo /usr/local/bin/jamf recon
}

function JAMFHelper() {
	windowType="fs"
	windowPostion="ul"
	alignDescription="center"
	alignHeading="center"

	jhHeading="${2}"
	jhDescription="Your Mac is being customized. This may take up to 30 minutes, depending on your network speed. Please call 1-800-527-4740 if you need any assistance."

	"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
	-windowType "$windowType" \
	-heading "$jhHeading" \
	-description "$jhDescription" \
	-icon "${3}" \
	-iconSize "${4}" \
	-alignDescription "$alignDescription" \
	-alignHeading "$alignHeading" &
	jamf policy -trigger "${1}"
}

echo "Running ProvisionEA Script"
ProvisionEA &
echo "Provision EA ran"
echo "Computer Name changing"
CompName &&
echo "Computer name changed"
echo "Running Recon"
Recon &&
echo "Recon ran"
echo "Running Configuration policies"
JAMFHelper Configurations "Congratulations ${LoggedInUser}" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbook-retina-space-gray.icns 768 &&
echo "Configurations policy finished"
echo "Running SoftwarePrep policy"
JAMFHelper SoftwarePrep "Preparing Setup" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns 256 &&
echo "Software policy ran"
echo "Running Symantec Policy"
JAMFHelper SymantecAV "Configuring Symantec Anti Virus" /usr/local/ti/icons/100-sep_app_icon.icns 256 &&
echo "Symantec policy ran"
echo "Running Encryption Policy"
JAMFHelper Encryption "Encrypting Hard Drive" /System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns 256 &&
echo "Encryption policy ran"
echo "Running Pulse Policy"
JAMFHelper VPN "Installing Pulse" /usr/local/ti/icons/102-pulse.icns 256 &&
echo "Pulse Policy ran"
echo "Running EC Policy"
JAMFHelper EC "Configuring Enterprise Connect" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns 256 &&
echo "EC policy ran"
echo "Running GP Policy"
JAMFHelper GP "Configuring Global Protect" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns 256 &&
echo "GP policy ran"
echo "Running YsoftInstall Policy"
JAMFHelper YsoftInstall "Configuring Printers" /usr/local/ti/icons/200-ySoft.icns 256 &&
echo "YsoftInstall policy ran"
echo "Running CrashPlan Policy"
JAMFHelper CrashPlan "Installing Crash Plan" /usr/local/ti/icons/201-CrashPlan.icns 256 &&
echo "CrashPlan policy ran"
echo "Running UI Policy"
JAMFHelper UI "Optimizing User Experience" /usr/local/ti/icons/300-UsersIcon.icns 256 &&
echo "UI policy ran"
echo "Running CacheMSOffice2016 Policy"
JAMFHelper CacheMSOffice2016 "Downloading Microsoft Office 2016" /usr/local/ti/icons/400-msOfficeInstaller.icns 256 &&
echo "CacheMSOffice2016 policy ran"
echo "Running InstallMSOffice2016 Policy"
JAMFHelper InstallMSOffice2016 "Installing Microsoft Office 2016" /usr/local/ti/icons/400-msOfficeInstaller.icns 256 &&
echo "InstallMSOffice2016 policy ran"
echo "Running Jabber Policy"
JAMFHelper Jabber "Installing Jabber" /usr/local/ti/icons/502-CiscoJabber.icns 256 &&
echo "Jabber policy ran"
echo "Running Plugins Policy"
JAMFHelper Plugins "Installing Internet Plugins" /Applications/Safari.app/Contents/Resources/compass.icns 256 &&
echo "Plugins policy ran"
echo "Running OSUpdates Policy"
JAMFHelper OSUpdates "Updating MacOS" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns 256 &&
echo "OSUpdates policy ran"
echo "Running Dock Policy"
JAMFHelper SetDockDefault "Setting Dock Defaults" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GridIcon.icns 256 &&
echo "Dock policy ran"
echo "Setting Provision plist"
SetProvision &&
echo "Provision Plist set"
echo "Running API Calls"
APICall "Status" "Deployed" &&
APICall "UserGroup" "Production" &&
echo "API calls ran"
echo "Running recon Policy"
Recon &&
echo "Recon policy ran"
echo "Running Wait Loop"
while true; do
	scepCompCert="BF0EC959-14B3-4C75-9CBF-5F2ED8C92858"
	scepCompCertDownload=$(/usr/bin/profiles -P | /usr/bin/grep "${scepCompCert}")

	scepUserCert="79B37066-233D-4046-A092-70E5FD97C1B5"
	scepUserCertDownload=$(/usr/bin/profiles -P | /usr/bin/grep "${scepUserCert}")

	if [[ ! -z "${scepCompCertDownload}" && ! -z "${scepUserCertDownload}" ]]; then
		break
	fi
	sleep 1
done
echo "Wait loop done"
echo "Removing cpn84"
sudo networksetup -removepreferredwirelessnetwork "en0" cpn84
echo "cpn84 removed"
echo "Running recon Policy"
Recon
echo "Recon policy ran"
sudo /usr/bin/killall jamfhelper
sudo /usr/bin/killall LockScreen

JAMFHelper Enjoy "Enjoy!" /usr/local/ti/icons/999-Success.icns 256

exit 0
