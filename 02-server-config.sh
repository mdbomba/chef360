#!/bin/bash
#
# Author Mike Bomba (mike.bomba@progress.com)
#
# SCRIPT TO DEFINE AND INSTALL INITIAL SKILLS TO CHEF360/COURIER
# SCRIPT WILL TEST AVAILABILITY OF CHEF360
# IF AVAILABLE, SCRIPT WILL ADD SKILLS, SETTINGS, AND OVERRIDES
# SCRIPT WILL SAVE VARIOUS PARAMETERS TO A FILE FOR FURTHER USE (./chef360-install.vars)
# SCRIPT REQUIRES ENITING OF PARAMETER SECTION BEFORE RUNNING
# SCRIPT SHOULD BE RUN UNDER USER LEVEL PERMISSIONS
#
# Input variables from previous scripts related to 1st time setup of chef360/courier
vars="./chef360.vars"
source $vars


## PARAMETERS 
skillAssemblyName='lab-skill_assembly' ; echo 'skillAssemblyName="'$skillAssemblyName'"'  >>  $vars
skillOverrideName='lab-skill-settings' ; echo 'skillOverrideName="'$skillOverrideName'"'  >>  $vars
cohortName='lab-skill-cohort-chef'     ; echo 'cohortName="'$cohortName'"'                >>  $vars
cohortDescription='lab skill cohort'   ; echo 'cohortDescription="'$cohortDescription'"'  >>  $vars
##

##  Test to see if chef360 instance is available
if curl $capi > /dev/null 2>&1 ; then echo "$capi is listening" ; else echo "$capi is not listening. Exiting script." ; exit; fi

##################################
## START REGISTRATION OF SKILLS ##
##################################
#
## DETERMINE ANY REGISTERED SKILLS
chef-node-management-cli management skill find-all-skills | jq .items | jq ".[]" > ./defined-skills.in
#
## REGISTER SKILL - register-agent
echo '{
"bldrUrl": "https://bldr.habitat.sh",
"bldrChannel": "stable",
"bldrAuthToken": "",
"nodeCheckinInterval": 3600,
"updateSkillMetadataInterval": 3600,
"logLevel": "debug"
}' > ./register-agent-skill.json
echo "REGISTERING SKILL - register-agent"
chef-node-management-cli management skill update-agent --body-file ./register-agent-skill.json
#
## REGISTER SKILL - courier-runner
echo '{
  "name":"courier-runner",
  "canister":{
    "name":"courier-runner",
    "origin":"chef-platform",
    "service":true
  },
  "configurationTemplates":[
    {
      "content":"W2xvZ10KZGlyID0gInt7LnNldHRpbmdzLmxvZ19kaXJ9fSIKZm9ybWF0ID0gInt7LnNldHRpbmdzLmxvZ19mb3JtYXR9fSIKbGV2ZWwgPSAie3suc2V0dGluZ3MubG9nX2xldmVsfX0iCm91dHB1dCA9ICJ7ey5zZXR0aW5ncy5sb2dfb3V0cHV0fX0iCgpbbm9kZV0Kbm9kZV9pZCA9ICJ7ey5hZ2VudC5ub2RlSWR9fSIKCnt7aWYgaW5kZXggLnNldHRpbmdzICJzaGVsbF9pbnRlcnByZXRlciJ9fQpbW2ludGVycHJldGVyc11dCm5hbWUgPSAie3suc2V0dGluZ3Muc2hlbGxfaW50ZXJwcmV0ZXJ9fSIKe3tlbmR9fQp7e2lmIGluZGV4IC5zZXR0aW5ncyAicmVzdGFydF9pbnRlcnByZXRlciJ9fQpbW2ludGVycHJldGVyc11dCm5hbWUgPSAie3suc2V0dGluZ3MucmVzdGFydF9pbnRlcnByZXRlcn19Igp7e2VuZH19Cnt7aWYgaW5kZXggLnNldHRpbmdzICJpbnNwZWNfaW50ZXJwcmV0ZXIifX0KW1tpbnRlcnByZXRlcnNdXQpuYW1lID0gInt7LnNldHRpbmdzLmluc3BlY19pbnRlcnByZXRlcn19Igp7e2VuZH19Cnt7aWYgaW5kZXggLnNldHRpbmdzICJjaGVmX2NsaWVudF9pbnRlcnByZXRlciJ9fQpbW2ludGVycHJldGVyc11dCm5hbWUgPSAie3suc2V0dGluZ3MuY2hlZl9jbGllbnRfaW50ZXJwcmV0ZXJ9fSIKe3tlbmR9fQoKW3JlcG9ydGVyXQpuYW1lID0gInt7LnNldHRpbmdzLnJlcG9ydGVyX25hbWV9fSIKYXV0aGVudGljYXRpb25UeXBlID0gICJ7ey5zZXR0aW5ncy5yZXBvcnRlcl9hdXRoZW50aWNhdGlvbl90eXBlfX0iCmRpciA9ICJ7ey5zZXR0aW5ncy5yZXBvcnRlcl9kaXJ9fSIKaW50ZXJuYWxJblNlYyA9IHt7LnNldHRpbmdzLnJlcG9ydGVyX2ludGVydmFsX2luX3NlY319CnJldHJ5SW50ZXJ2YWxJblNlYyA9IHt7LnNldHRpbmdzLnJlcG9ydGVyX3JldHJ5X2ludGVydmFsX2luX3NlY319CnRvdGFsUmV0cnlEdXJhdGlvbkluTWluID0ge3suc2V0dGluZ3MucmVwb3J0ZXJfdG90YWxfcmV0cnlfZHVyYXRpb25faW5fbWlufX0KCltnYXRld2F5X2NvbmZpZ10KdGVuYW50ZnFkbnMgPSAie3suYWdlbnQudGVuYW50RnFkbnN9fSIKbm9kZV9yb2xlX2xpbmtfaWQgPSAie3suc2tpbGwubm9kZVJvbGVMaW5rSWR9fSIKcGxhdGZvcm1fY3JlZGVudGlhbF9wYXRoID0gInt7LnNraWxsLnBsYXRmb3JtQ3JlZGVudGlhbHNQYXRofX0iCnJvb3RfY2FfcGF0aCA9ICJ7ey5hZ2VudC5yb290Q2FQYXRofX0iCmluc2VjdXJlID0gInt7LmFnZW50Lmluc2VjdXJlfX0iCgpbcXVldWVdCnByb3ZpZGVyID0gMA==",
      "fileName":"user.toml",
      "filePath":"/hab/user/courier-runner/config",
      "name":"courier-runner-template",
      "windowsFilePath":"c:\\hab\\user\\courier-runner\\config"
    }
  ]
}' > ./courier-runner-skill.json
if ! grep 'courier-runner' ./defined-skills.in >/dev/null 2>&1 ; then 
    echo "REGISTERING SKILL - courier-runner"
    chef-node-management-cli management skill create-skill --body-file ./courier-runner-skill.json
else
    echo "SKILL ALREADY REGISTERED - courier-runner"
fi
#
## REGISTER SKILL - chef-gohi
echo '{
    "name": "chef-gohai",
    "canister": {
        "origin": "chef-platform",
        "name": "chef-gohai",
        "service": true
    },
    "configurationTemplates": [
        {
            "content": "W2dvaGFpXQpub2RlX2lkID0gInt7LmFnZW50Lm5vZGVJZH19Igpub2RlX3JvbGVfbGlua19pZCA9ICJ7ey5za2lsbC5ub2RlUm9sZUxpbmtJZH19IgpwbGF0Zm9ybV9jcmVkZW50aWFsc19wYXRoID0gInt7LnNraWxsLnBsYXRmb3JtQ3JlZGVudGlhbHNQYXRofX0iCmluc2VjdXJlID0ge3suYWdlbnQuaW5zZWN1cmV9fQpyb290X2NhX3BhdGggPSAie3suYWdlbnQucm9vdENhUGF0aH19IgoKW2FwaV0KdGVuYW50X2ZxZG5zID0gInt7LmFnZW50LnRlbmFudEZxZG5zfX0iCgpbbG9nZ2VyXQpsb2dfbGV2ZWwgPSAie3suc2V0dGluZ3MubG9nX2xldmVsfX0i",
            "fileName": "user.toml",
            "filePath": "/hab/user/chef-gohai/config",
            "name": "default",
            "windowsFilePath": "c:\\hab\\user\\chef-gohai\\config"
        }
    ]
}' > ./gohai-skill.json
if ! grep 'chef-gohai' ./defined-skills.in >/dev/null 2>&1 ; then
    echo "REGISTERING SKILL - chef-gohi"
    chef-node-management-cli management skill create-skill --body-file ./gohai-skill.json
else
    echo "SKILL ALREADY REGISTERED - chef-gohi"
fi
#
## REGISTERING SKILL - shell-interpreter 
echo '{
    "name": "shell-interpreter",
    "canister": {
        "origin": "chef-platform",
        "name": "shell-interpreter",
        "service": false
    },
    "configurationTemplates": []
}' > ./shell-interpreter-skill.json
if ! grep 'shell-interpreter' ./defined-skills.in >/dev/null 2>&1 ; then
    echo "REGISTERING SKILL - shell-interpreter"
    chef-node-management-cli management skill create-skill --body-file ./shell-interpreter-skill.json
else
    echo "SKILL ALREADY REGISTERED - shell-interpreter"
fi
#
## REGISTER SKILL - restart-interpreter
echo '{
  "name": "restart-interpreter",
  "canister": {
    "origin": "chef-platform",
    "name": "restart-interpreter",
    "service": false
  },
  "configurationTemplates": []
}' > ./restart-interpreter-skill.json
if ! grep 'restart-interpreter' ./defined-skills.in >/dev/null 2>&1 ; then
    echo "REGISTERING SKILL - restart-interpreter"
    chef-node-management-cli management skill create-skill --body-file ./restart-interpreter-skill.json
else
    echo "SKILL ALREADY REGISTERED - restart-interpreter"
fi
#
## REGISTER SKILL - chef-client-interpreter
echo '{
  "name": "chef-client-interpreter",
  "canister": {
    "origin": "chef-platform",
    "name": "chef-client-interpreter",
    "service": false
  },
  "configurationTemplates": []
}' > ./chef-client-interpreter-skill.json
if ! grep 'chef-client-interpreter' ./defined-skills.in >/dev/null >/dev/null 2>&1 ; then
    echo "REGISTERING SKILL - chef-client-interpreter"
    chef-node-management-cli management skill create-skill --body-file ./chef-client-interpreter-skill.json
else
    echo "SKILL ALREADY REGISTERED - chef-client-interpreter"
fi
#
## REGISTER SKILL - inspec-interpreter
echo '{
  "name": "inspec-interpreter",
  "canister": {
    "origin": "chef-platform",
    "name": "inspec-interpreter",
    "service": false
  },
  "configurationTemplates": []
}' > ./inspec-interpreter-skill.json
if ! grep 'inspec-interpreter' ./defined-skills.in >/dev/null 2>&1 ; then
    echo "REGISTERIG SKILL - inspec-interpreter"
    chef-node-management-cli management skill create-skill --body-file ./inspec-interpreter-skill.json
else
    echo "SKILL ALREADY REGISTERED - inspec-interpreter"
fi
#
###################################
## END OF REGISTRATION OF SKILLS ##
###################################
#
###################################
##    START OF SKILLS ASSEMBLY   ##
###################################
#
chef-node-management-cli management assembly find-all-assemblies > ./skills-assembly.in
#
## CREATE SKILL ASSEMBLY
echo '{
  "name": "'"$skillAssemblyName"'",
  "skills": [
    {
      "action": "add",
      "skill": {
        "channel": "stable",
        "name": "courier-runner",
        "value": ["1.4.2"]
      }
    },
    {
      "action": "add",
      "skill": {
        "channel": "stable",
        "name": "chef-gohai",
        "value": ["1.0.1"]
      }
    },
    {
      "action": "add",
      "skill": {
        "channel": "stable",
        "name": "shell-interpreter",
        "value": ["1.0.2"]
      }
    },
    {
      "action": "add",
      "skill": {
        "channel": "stable",
        "name": "inspec-interpreter",
        "value": ["1.0.3"]
      }
    },    {
      "action": "add",
      "skill": {
        "channel": "stable",
        "name": "restart-interpreter",
        "value": ["1.0.1"]
      }
    },
    {
      "action": "add",
      "skill": {
        "channel": "stable",
        "name": "chef-client-interpreter",
        "value": ["1.0.3"]
      }
    }
  ]
}' > ./skill-assembly.json
if ! grep "$skillAssemblyName" ./skills-assembly.in > /dev/null 2>&1 ; then
    echo "REGISTERING SKILL ASSEMBLY - $skillAssemblyName"
    chef-node-management-cli management assembly create-assembly --body-file skill-assembly.json | tee ./skill-assembly.out
    skillAssemblyId="$(cat ./skill-assembly.out | jq .item | jq .skillAssemblyId | tr -d '"')"
    echo 'skillAssemblyName="'$skillAssemblyName'"' >>  $vars
    echo 'skillAssemblyId="'$skillAssemblyId'"' >>  $vars
else
    echo "SKILL ASSEMPLY ALREADY REGISTERED - $skillAssemblyName"
fi
#
## CREATE SKILL ASSEMPLY SETTINGS (skill override)
echo '{
  "name":"'"$skillOverrideName"'",
  "skills":[
    {
      "skillName":"chef-gohai",
      "settings":[
        {
          "name":"log_level",
          "value":"debug"
        }
      ]
    },
    {
      "skillName":"courier-runner",
      "settings":[
        {
          "name":"credentials_api_key",
          "value":""
        },
        {
          "name":"credentials_api_secret",
          "value":""
        },
        {
          "name":"shell_interpreter",
          "value":"chef-platform/shell-interpreter"
        },
        {
          "name":"restart_interpreter",
          "value":"chef-platform/restart-interpreter"
        },
        {
          "name":"inspec_interpreter",
          "value":"chef-platform/inspec-interpreter"
        },
        {
          "name":"chef_client_interpreter",
          "value":"chef-platform/chef-client-interpreter"
        },
        {
          "name":"log_dir",
          "value":"/hab/svc/courier-runner/logs"
        },
        {
          "name":"log_format",
          "value":"json"
        },
        {
          "name":"log_level",
          "value":"debug"
        },
        {
          "name":"log_output",
          "value":"file"
        },
        {
          "name":"queue_provider",
          "value":"0"
        },
        {
          "name":"reporter_authentication_type",
          "value":"basic"
        },
        {
          "name":"reporter_dir",
          "value":"/hab/svc/courier-runner/data"
        },
        {
          "name":"reporter_host_url",
          "value":""
        },
        {
          "name":"reporter_interval_in_sec",
          "value":"3"
        },
        {
          "name":"reporter_name",
          "value":"server"
        },
        {
          "name":"reporter_retry_interval_in_sec",
          "value":"4"
        },
        {
          "name":"reporter_total_retry_duration_in_min",
          "value":"2"
        }
      ]
    }
  ]
}' > ./node-override-setting.json
chef-node-management-cli management setting find-all-settings > ./skills-override.in
if ! grep "$skillOverrideName" ./skills-override.in > /dev/null 2>&1 ; then
    echo "DEFINING SKILL SETTINGS (node override) - $skillOverrideName"
    chef-node-management-cli management setting create-setting --body-file ./node-override-setting.json | tee ./skills-override.out
    settingId="$(cat ./skills-override.out | jq .item | jq .settingId | tr -d '"' )"
    echo 'skillOverrideName="'$skillOverrideName'"' >>  $vars
    echo 'settingName="'$skillOverrideName'"' >>  $vars
    echo 'settingId="'$settingId'"' >>  $vars
else
    echo "SKILLS SETTINGS ALREADY DEFINED - $skillOverrideName"
fi
#
## CREATE NODE COHORT
echo '
{
  "name": "'"$cohortName"'",
  "description": "'"$cohortDescription"'",
  "settingId": "'"$settingId"'",
  "skillAssemblyId":"'"$skillAssemblyId"'"
}' > node-cohort.json
###
## Conditionally install node cohort

chef-node-management-cli management cohort find-all-cohorts > node-cohort.in
if ! grep "$cohortName" ./node-cohort.in > /dev/null 2>&1 ; then
    echo "DEFINING NODE COHORT - $cohortName"
    chef-node-management-cli management cohort create-cohort --body-file node-cohort.json | tee  ./node-cohort.out
    cohortId="$(cat ./node-cohort.out | jq .item | jq .cohortId | tr -d '"' )"
    echo 'cohortName="'$cohortName'"' >>  $vars
    echo 'cohortId="'$cohortId'"' >>  $vars
else
    echo "NODE COHORT ALREADY DEFINED - $cohortName"
fi



echo ''
echo "Chef360 Skills Process Completed.  Current parameters are stored in file $vars"
echo ''
cat $vars
##

# END OF SCRIPT





