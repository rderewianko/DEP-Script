#!/bin/bash

#####################################################################################
# SCRIPT: DEP Test Basic - Office & OS Updates & Config
#
# DESCRIPTION: DEP Script which includes a single Cache and Install of Microsoft Office,
#               OS Updates, and Configuration Profiles as Policies.
#
# VERSION: 1.1.0
#####################################################################################

JSSAPIpass="${4}"

function SetProvision() {
    sudo /usr/libexec/PlistBuddy -c "Set :Status Provisioned" -c "Set :ProvisioningScript 1.1.0" /usr/local/ti/com.ti.provisioned.plist
}

function Recon() {
	sudo /usr/local/bin/jamf recon
}

function Policy() {
	sudo /usr/local/bin/jamf policy
}

function CompName() {
    cType=$(/usr/sbin/system_profiler SPHardwareDataType | grep 'Model Name:' | awk -F': ' '{print substr($2,1,7)}')
    sNumber=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	if [ "${cType}" == "MacBook" ]; then
		/usr/sbin/scutil --set ComputerName "L${sNumber}"
		/usr/sbin/scutil --set LocalHostName "L${sNumber}"
		/usr/sbin/scutil --set HostName "L${sNumber}"
		/usr/bin/defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName "L${sNumber}"
	else
		/usr/sbin/scutil --set ComputerName  "D${sNumber}"
		/usr/sbin/scutil --set LocalHostName "D${sNumber}"
		/usr/sbin/scutil --set HostName "D${sNumber}"
		/usr/bin/defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName "D${sNumber}"
	fi
}

function DHCPinfo() {
  MACaddress=$(/sbin/ifconfig en0 | awk '/ether/{print $2}')
	ClientID="CaliFruitCo-${MACaddress}"
	echo "Client DHCP IP Information"
	echo "************************************************************"
	/usr/sbin/networksetup -detectnewhardware
	IFS=$'\n'
	    for i in $(/usr/sbin/networksetup -listallnetworkservices | tail +2 );
	    do
	        echo "${i} is set to Client ID: ${ClientID}"
	        /usr/sbin/networksetup -setdhcp "${i}" "${ClientID}"
	        echo "Set Client ID for ${i} to ${ClientID}"
	    done
	unset "${IFS}"
	echo " "
}

function Wireless() {
	productionSSID="halekoa75"
	provisioningSSID="cpn84"
	wifiOrAirport=$(/usr/sbin/networksetup -listallnetworkservices | grep -Ei '(Wi-Fi|AirPort)')
	wirelessDevice=$(/usr/sbin/networksetup -listallhardwareports | awk "/${wifiOrAirport}/,/Device/" | awk 'NR==2' | cut -d " " -f 2)
	prefferedNetworks=$(/usr/sbin/networksetup -listpreferredwirelessnetworks "${wirelessDevice}")
	echo "Updating Wireless SSID remove ${provisioningSSID}"
	echo "************************************************************"
	echo "Available Wireless Device:" "${wifiOrAirport}"
	echo "${prefferedNetworks}"

	until echo "${prefferedNetworks}" | grep !q "${provisioningSSID}"; do
		/usr/sbin/networksetup -removepreferredwirelessnetwork "${wirelessDevice}" "${provisioningSSID}"
	done

	sudo /usr/local/bin/jamf recon
}

CompType=`/usr/sbin/system_profiler SPHardwareDataType | grep 'Model Name:' | awk -F': ' '{print substr($2,1)}'`
LoggedInUser=`/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RealName:0" /dev/stdin <<< "$(dscl -plist . -read /Users/$(stat -f%Su /dev/console) RealName)"`

# get Screen Size
#######################################################################################################################
resolution=`system_profiler SPDisplaysDataType |grep Resolution | awk '{print$2,$3,$4}'	`

if [ "${resolution}" == "1366 x 768" ]; then
	screen="11\""
	elif [ "${resolution}" == "2560 x 1600" ] || [ "${resolution}" == "1440 by 900" ]; then
	screen="13\""
	elif [ "${resolution}" == "2880 x 1800" ]; then
	screen="15\""
	elif [ "${resolution}" == "1920 x 1080" ] || [ "${resolution}" == "4096 by 2304" ]; then
	screen="21\""
	elif [ "${resolution}" == "5120 x 2880" ]; then
	screen="27\""
fi

model="${screen} ${CompType} ${isRetina}"
ModelIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbook-retina-space-gray.icns"

# JAMF Helper Variables
#######################################################################################################################
	windowType="fs"				#	[hud | utility | fs]
	windowPostion="ul"			#	[ul | ll | ur | lr]
	iconSize="256"				#	pixels
	alignDescription="center"	#	[right | left | center | justified | natural]
	alignHeading="center" 		#	[right | left | center | justified | natural]

# Screen 001 - Welcome
#######################################################################################################################
policyName="ConfigProf"
jhHeading="Congratulations ${LoggedInUser}"
jhDescription="Your ${model} is being customized. This may take up to 30 minutes, depending on your network speed."

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "${ModelIcon}" \
-iconSize "768" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

CompName && Recon && DHCPinfo && Recon

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 002 - Preparing Setup
#######################################################################################################################
policyName="SoftwarePrep"
jhHeading="Preparing Setup"
jhDescription="Your ${model} is being customized. This may take up to 30 minutes, depending on your network speed."
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 100 - Install Symantec Anti Virus
#######################################################################################################################
policyName="SymantecAV"
jhHeading="Configuring Symantec Anti Virus"
icon="/usr/local/ti/icons/100-sep_app_icon.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 101 - File Vault
#######################################################################################################################
policyName="Encryption"
jhHeading="Encrypting Hard Drive"
icon="/System/Library/PreferencePanes/Security.prefPane/Contents/Resources/FileVault.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 102 - Install Pulse Client
#######################################################################################################################
policyName="VPN"
jhHeading="Configuring Pulse Client"
icon="/usr/local/ti/icons/102-pulse.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 103 - Install Apple Enterprise Connect
#######################################################################################################################
policyName="EC"
jhHeading="Configuring Global Protect"
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 104 - Install Global Protect
#######################################################################################################################
policyName="GP"
jhHeading="Configuring Global Protect"
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 200 - Printer: Xerox Driver, non-admin print, CUPS enabled
#######################################################################################################################
policyName="YsoftInstall"
jhHeading="Installing Printer Drivers"
icon="/usr/local/ti/icons/200-ySoft.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 201 - Install Crash Plan
#######################################################################################################################
policyName="CrashPlan"
jhHeading="Installing Crash Plan"
icon="/usr/local/ti/icons/201-CrashPlan.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 300 - User Experience: Non Admin Wifi, MenuBar Icons
#######################################################################################################################
policyName="UI"
jhHeading="Optimizing User Experience"
icon="/usr/local/ti/icons/300-UsersIcon.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 498 - Cache Microsoft Office
#######################################################################################################################
policyName="CacheMSOffice2016"
jhHeading="Downloading Microsoft Office 2016"
icon="/usr/local/ti/icons/400-msOfficeInstaller.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 499 - Install Microsoft Office
#######################################################################################################################
policyName="InstallMSOffice2016"
jhHeading="Installing Microsoft Office 2016"
icon="/usr/local/ti/icons/400-msOfficeInstaller.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 502 - Install Jabber
#######################################################################################################################
policyName="Jabber"
jhHeading="Installing Jabber"
icon="/usr/local/ti/icons/502-CiscoJabber.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 800 - Internet Plugins
#######################################################################################################################
policyName="Plugins"
jhHeading="Installing Internet Plugins"
icon="/Applications/Safari.app/Contents/Resources/compass.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon"  \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 850 - MacOS Updates
#######################################################################################################################
policyName="OSUpdates"
jhHeading="Updating MacOS"
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}"  \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Wireless
#######################################################################################################################
jhHeading="Updating Wireless Connection"
icon="/System/Library/CoreServices/Applications/Wireless Diagnostics.app/Contents/Resources/WirelessDiagnostics.icns"
wifiOrAirport=$(/usr/sbin/networksetup -listallnetworkservices | grep -Ei '(Wi-Fi|AirPort)')
wirelessDevice=$(networksetup -listallhardwareports | awk "/$wifiOrAirport/,/Device/" | awk 'NR==2' | cut -d " " -f 2)
productionSSID="halekoa75"
provisioningSSID="cpn84"
prefferedNetworks=$(/usr/sbin/networksetup -listpreferredwirelessnetworks "$wirelessDevice")
updatedSSID=$(/usr/sbin/networksetup -listpreferredwirelessnetworks "$wirelessDevice")

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}" \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &
echo "Available Wireless Device:" "${wifiOrAirport}"
echo "${prefferedNetworks}"

/usr/sbin/networksetup -removepreferredwirelessnetwork "${wirelessDevice}" "${provisioningSSID}"
echo "Removed SSID:" "${provisioningSSID}"

killall jamfhelper

# EA API Call for Status and User Group
function APICall()
{
    jssURL="https://jssdmz.ext.ti.com:8443/JSSResource"
    serial=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
    jssAPIUser="jssapi"
    jssAPIPass="${JSSAPIpass}"

    echo "<?xml version='1.0' encoding='UTF-8' standalone='no'?>
    <computer>
    	<extension_attributes>
    		<attribute>
    			<name>${1}</name>
    			<value>${2}</value>
    		</attribute>
    	</extension_attributes>
    </computer>
    " > /tmp/test.xml

    curl -k -v -u "${jssAPIUser}":"${jssAPIPass}" "${jssURL}"/computers/serialnumber/"${serial}"/subset/extensionattributes -T "/tmp/test.xml" -X PUT
    rm /tmp/test.xml
}

# Screen 997 - Dock Default
#######################################################################################################################
policyName="SetDockDefault"
jhHeading="Setting up Dock"
icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description "${jhDescription}"  \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &

jamf policy -trigger "${policyName}"

killall jamfhelper

# Screen 999 - Complete
#######################################################################################################################
policyName="Enjoy"
jhHeading="Enjoy!"
icon="/usr/local/ti/icons/999-Success.icns"

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfhelper" \
-windowType "${windowType}" \
-title "${jhTitle}" \
-heading "${jhHeading}" \
-description " "  \
-icon "$icon" \
-iconSize "$iconSize" \
-alignDescription "${alignDescription}" \
-alignHeading "${alignHeading}" &
SetProvision && APICall "Status" "Deployed" && APICall "UserGroup" "Production" && Recon &&
jamf policy -trigger "${policyName}"

killall jamfhelper

exit 0
