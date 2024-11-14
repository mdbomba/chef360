#!/bin/bash
#
# Author: Mike Bomba (mike.bomba@progress.com)
# Date: 20241106
#
# SCRIPT TO ADD A WORKSTATION TO CHEF360/COURIER
# SCRIPT WILL TEST AVAILABILITY OF CHEF360
# IF AVAILABLE, SCRIPT WILL ADD WORKSTATION AND ADD 3 PROFILES (tenant admin, org admin, default admin)
# SCRIPT WILL SAVE NAMES AND IDs FOR ADMINS TO A FILE FOR FURTHER USE (./chef360-install.vars)
# SCRIPT REQUIRES ENITING OF PARAMETER SECTION BEFORE RUNNING
# SCRIPT SHOULD BE RUN UNDER USER LEVEL PERMISSIONS
#
#
## EDITABLE PARAMETERS ##
workstation= hostname -s
chef360='courier.kemptech.biz'
orgAdmin='chef' 
tenantAdmin='lab'
defaultAdmin='chef'
#
# VERIFY EDITABLE PARAMETER (workstation)
read -p "Do you want to keep the value for Chef Workstation ($workstation) (y/n): " keep ; echo $keep
if [ "$keep" = "n" ]; then read -p  "Enter new value for Chef Workstation: " workstation ; fi
while ! ping -c 2 $workstation > /dev/null 2>&1 
do read -p  "Host failed ping test. Enter new value for Chef Workstation: " workstation; done  
#
# VERIFY EDITABLE PARAMETER (chef360)
read -p "Do you want to keep the value for Chef 360 server ($chef360) (y/n): " keep ; echo $keep
if [ "$keep" = "n" ]; then read -p  "Enter new FQDN for Chef 360 server: " chef360 ; fi
while ! ping -c 2 $workstation > /dev/null 2>&1 
do read -p  "Host failed ping test. Enter new FQDN for Chef 360 server: " chef360; done  
#
# VERIFY EDITABLE PARAMETER (orgAdmin)
read -p "Do you want to keep the value for Chef 360 Org Admin ($orgAdmin) (y/n): " keep ; echo $keep
if [ "$keep" = "n" ]; then read -p  "Enter new value for Chef 360 Org Admin: " orgAdmin ; fi
#
# VERIFY EDITABLE PARAMETER (tenantAdmin)
read -p "Do you want to keep the value for Chef 360 Tenant Admin ($tenantAdmin) (y/n): " keep ; echo $keep
if [ "$keep" = "n" ]; then read -p  "Enter new value for Chef 360 Tenant Admin: " tenantAdmin ; fi
#
# VERIFY EDITABLE PARAMETER (defaultAdmin)
read -p "Do you want to keep the value for Chef 360 Default Admin ($defaultAdmin) (y/n): " keep ; echo $keep
if [ "$keep" = "n" ]; then read -p  "Enter new value for Chef 360 Default Admin: " defaultAdmin ; fi
#
## CALCULATE VALUE OF Chef360 API (capi)
capi="none"
if curl http://$chef360:31000 > /dev/null 2>&1; then 
  capi="http://$chef360:31000"
fi
if curl https://$chef360:31000 > /dev/null 2>&1; then 
  capi="https://$chef360:31000"
fi
if [ $capi = "none" ]; then echo "ERROR API INTERFACE NOT FOUND. SCRIPT EXITING."; exit; fi
#
## NONEDITABLE PARAMETERS
creds="$HOME/.chef-platform/credentials"
credFile="$HOME/.chef-platform/credentials"
vars="./chef360.vars"
#
## CREATE PARAMETERS FILE FOR INSTALLING AND CONFIGURING CHEF360 AND COURIER
echo 'workstation="'$workstation'"'    >  $vars
echo 'chef360="'$chef360'"'           >>  $vars
echo 'orgAdmin="'$orgAdmin'"'         >>  $vars
echo 'tenantAdmin="'$tenantAdmin'"'   >>  $vars
echo 'defaultAdmin="'$defaultAdmin'"' >>  $vars
echo 'capi="'$capi'"'                 >>  $vars
echo 'credFile="'$credFile'"'         >>  $vars
#
## TOOLS INSTALL (chef-platform-auth-cli)
if test `command -v chef-platform-auth-cli`; then echo 'chef-platform-auth-cli already installed'; else 
curl -sk "$capi/platform/bundledtools/v1/static/install.sh" | TOOL="chef-platform-auth-cli" SERVER="$capi" VERSION="latest" bash - > /dev/null 2>&1
fi
#
## TOOLS INSTALL (chef-node-management-cli)
if test `command -v chef-node-management-cli`; then echo 'chef-node-management-cli already installed'; else 
curl -sk "$capi/platform/bundledtools/v1/static/install.sh" | TOOL="chef-node-management-cli" SERVER="$capi" VERSION="latest" bash - > /dev/null 2>&1
fi
#
## TOOLS INSTALL (chef-courier-cli)
if test `command -v chef-courier-cli`; then echo 'chef-courier-cli already installed'; else 
curl -sk "$capi/platform/bundledtools/v1/static/install.sh" | TOOL="chef-courier-cli" SERVER="$capi" VERSION="latest" bash - > /dev/null 2>&1
fi
#
## DETERMINE LEVEL OF WORKSTATION AND ACCOUNT REGISTRATION
if test -f $credFile && grep $orgAdmin $credFile > /dev/null 2>&1 ; then echo "$orgAdmin credential exists."; doIrgAdmin=0; else doOrgAdmin=1; fi
if test -f $credFile && grep $tenantAdmin $credFile > /dev/null 2>&1 ; then echo "$tenantAdmin credential exists."; doTenantAdmin=0; else doTenantAdmin=1; fi
if test -f $credFile && grep "default" $credFile > /dev/null 2>&1 ; then echo "default credential exists.";doDefaultAdmin=0; else doDefaultAdmin=1; fi
#
## CONDITIONALLY REGISTER WORKSTATION AND ACCOUNTS
if $doTenantAdmin; then 
    echo "Registering workstation profile - $tenantAdmin. USE TENANT LOGIN OPTION WHEN FOLLOWING LINK."
    chef-platform-auth-cli register-device --device-name "$workstation" --profile-name "$tenantAdmin" --url "$capi" --insecure 
fi
if $doOrgAdmin; then 
    echo "Registering workstation profile - $orgAdmin. USE TENANT LOGIN OPTION WHEN FOLLOWING LINK."
    chef-platform-auth-cli register-device --device-name "$workstation" --profile-name "$orgAdmin" --url "$capi" --insecure
fi
if $doDefaultAdmin; then 
    echo "Registering $defaultAdmin as the default admin account for workstation - $workstation"
    chef-platform-auth-cli set-default-profile "$defaultAdmin" 
fi
#
## DISPLAY ADMIN INFO
echo 'Display all admin roles'
echo ''
echo "PROFILE TYPE  PROFILE NAME                        PROFILE ID"
echo "------------  ----------------         ------------------------------------"
echo "default       default                  $defaultAdmin"
echo "tenant        $tenantAdmin             $tenantAdmin"
echo "org           $orgAdmin                $orgAdmin"
echo ""
##
# END OF SCRIPT
