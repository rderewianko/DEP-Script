#!/bin/bash

########################################################################################
# SCRIPT: DEP 2.0.0
#
# DESCRIPTION: DEP Script 2.0.0
#
# VERSION: 2.0.0
########################################################################################

LoggedInUser=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RealName:0" /dev/stdin <<< "$(dscl -plist . -read /Users/$(stat -f%Su /dev/console) RealName)")

function SetProvision() {
  sudo /usr/libexec/PlistBuddy -c "Set :ProvisioningScript 2.0.0" -c "Set :Status Provisioned" /usr/local/ti/com.ti.provisioned.plist
}

function CompName() {
    CompType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Name")
    SerialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
  if [ "${CompType}" == *"MacBook"* ]; then
    CompName="L${SerialNumber}"
  else
    CompName="D${SerialNumber}"
  fi
		/usr/sbin/scutil --set ComputerName  "${CompName}"
		/usr/sbin/scutil --set LocalHostName "${CompName}"
		/usr/sbin/scutil --set HostName "${CompName}"
    /usr/bin/defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName "${CompName}"
}

function LockScreen() {
  sudo /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/MacOS/LockScreen -session 256
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

function ScreenSize() {
	ModelQuery=$(system_profiler SPHardwareDataType | grep "Model Name")
	ModelName="${ModelQuery##*:}"

  resolution=$(system_profiler SPDisplaysDataType | grep Resolution | awk '{print$2,$3,$4}')
    ScreenSize=`
      case "${resolution}" in
        "1366 x 768")                  echo "11";;
        "2560 x 1600" | "1440 x 900")  echo "13";;
        "2880 x 1800")                 echo "15";;
        "1920 x 1080" | "4096 x 2304") echo "21";;
        "5120 x 2880")                 echo "27";;
      esac
      `

	Model="${ScreenSize}\"${ModelName}"

	echo "${Model}"
}

function JAMFHelper() {
	windowType="fs"
	windowPostion="ul"
	alignDescription="center"
	alignHeading="center"

	jhHeading="${2}"
	jhDescription="Your $(ScreenSize) is being customized. This may take up to 30 minutes, depending on your network speed."

	"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
	-windowType "$windowType" \
	-title "$jhTitle" \
	-heading "$jhHeading" \
	-description "$jhDescription" \
	-icon "${3}" \
	-iconSize "${4}" \
	-alignDescription "$alignDescription" \
	-alignHeading "$alignHeading" &
	jamf policy -trigger "${1}"
}

CompName &&
LockScreen &
Recon &&
JAMFHelper Configurations "Congratulations ${LoggedInUser}" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbook-retina-space-gray.icns 768 &&
JAMFHelper SoftwarePrep "Preparing Setup" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns 256 &&
JAMFHelper SymantecAV "Configuring Symantec Anti Virus" /usr/local/ti/icons/100-sep_app_icon.icns 256 &&
JAMFHelper Encryption "Encrypting Hard Drive" /System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns 256 &&
JAMFHelper VPN "Configuring Pulse Client" /usr/local/ti/icons/102-pulse.icns 256 &&
JAMFHelper EC "Configuring Enterprise Connect" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns 256 &&
JAMFHelper GP "Configuring Global Protect" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns 256 &&
JAMFHelper YsoftInstall "Configuring Printers" /usr/local/ti/icons/200-ySoft.icns 256 &&
JAMFHelper CrashPlan "Installing Crash Plan" /usr/local/ti/icons/201-CrashPlan.icns 256 &&
JAMFHelper UI "Optimizing User Experience" /usr/local/ti/icons/300-UsersIcon.icns 256 &&
JAMFHelper CacheMSOffice2016 "Downloading Microsoft Office 2016" /usr/local/ti/icons/400-msOfficeInstaller.icns 256 &&
JAMFHelper InstallMSOffice2016 "Installing Microsoft Office 2016" /usr/local/ti/icons/400-msOfficeInstaller.icns 256 &&
JAMFHelper Jabber "Installing Jabber" /usr/local/ti/icons/502-CiscoJabber.icns 256 &&
JAMFHelper Plugins "Installing Internet Plugins" /Applications/Safari.app/Contents/Resources/compass.icns 256 &&
JAMFHelper OSUpdates "Updating MacOS" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns 256 &&
APICall "Status" "Deployed" &&
APICall "UserGroup" "Production" &&
SetProvision &&
JAMFHelper WirelessUpdate "Wireless Network Configuration" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns 256 &&
JAMFHelper Enjoy "Complete" /usr/local/ti/icons/999-Success.icns 256

exit 0
