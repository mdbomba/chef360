vars="./chef360.vars"
source $vars

outFile="./job-out.json"
inFile='./job-in.json'

jobName='100-courier-lab-nginx-7'
jobDesc='Rolling Jobs'

jId=$(chef-courier-cli scheduler jobs list-jobs --pagination.size 10000 | jq -r --arg name "$jobName" '.items | .[] | select(.name==$name) | .id')
echo "$jId"
echo "$jobId"

if [ "$jId" = "$jobId" ]; then doit=1; echo 'match'; else doit=0; echo 'nomatch'; fi



if [ $doit ]; then
    echo "Rerunning existing job named $jobName"
    # CLEAN OUT OLD JOB NAMES AND IDS FROM VARS FILE
    grep -v 'jobName' $vars > $vars.1
    grep -v 'jobId' $vars.1 > $vars.2
    grep -v 'jobStatus' $vars.2 > $vars.3
    grep -v 'instanceId' $vars.3 > $vars.4
    grep -v 'runId' $vars.4 > $vars
    rm -rf $vars.*
    chef-courier-cli scheduler jobs activated-job --jobId "$jId" | jq | tee $outFile 2>&1
    jobId="$(cat $outFile | jq -r '.item | .id')"
else
    echo "Running new job named $jobName"
    # CLEAN OUT OLD JOB NAMES AND IDS FROM VARS FILE
    grep -v 'jobName' $vars > $vars.1
    grep -v 'jobId' $vars.1 > $vars.2
    grep -v 'jobStatus' $vars.2 > $vars.3
    grep -v 'instanceId' $vars.3 > $vars.4
    grep -v 'runId' $vars.4 > $vars
    rm -rf $vars.*

cat <<EOF > $inFile
{
  "name": "$jobName",
  "description": "$jobDesc",
  "exceptionRules": [],
  "scheduleRule": "immediate",
  "target": {
    "executionType": "sequential",
    "groups": [
      {
        "timeoutSeconds": 120,
        "batchSize": {
          "type": "percent",
          "value": 100
        },
        "distributionMethod": "batching",
        "successCriteria": [
          {
            "status": "success",
            "numRuns": {
              "type": "percent",
              "value": 100
            }
          }
        ],
        "nodeListType": "filter",
        "filter": {
          "constraints": {
            "attributes": [
              {
                "name": "primary_ip",
                "operator": "MATCHES",
                "value": [
                  "$nodeIp"
                ]
              }
            ]
          }
        }
      }
    ]
    },
    "actions": {
        "accessMode": "agent",
        "steps": [
            {
                "interpreter": {
                  "skill": {
                    "minVersion": "1.0.0"
                  },
                  "name": "chef-platform/shell-interpreter"
                },
                "command": {
                  "linux": [
                    "which nginx >/dev/null && echo true || echo false"
                ]
              },
                "inputs": {},
                "expectedInputs": {},
                "outputFieldRules": {
                    "NGINX_FOUND": {
                        "source": "stdout",
                        "sourceType": "output",
                        "extractMethod": "content",
                        "expression": "",
                        "required": true,
                        "sensitive": false
                    }
                },
                "retryCount": 2,
                "failureBehavior": {
                    "action": "retryThenFail",
                    "retryBackoffStrategy": {
                        "type": "linear",
                        "delaySeconds": 1,
                        "arguments": []
                    }
                },
                "limits": {},
                "conditions": [],
                "name": "a step to check nginx presence"
            },
            {
                "interpreter": {
                  "skill": {
                    "minVersion": "1.0.0"
                  },
                  "name": "chef-platform/shell-interpreter"
                },
                "inputs": {},
                "expectedInputs": {
                    "NGINX_FOUND": {
                        "type": "string",
                        "sensitive": false,
                        "required": true,
                        "default": ""
                    }
                },
                "outputFieldRules": {},
                "conditions": [
                    {
                        "inputName": "NGINX_FOUND",
                        "operator": "eq",
                        "value": "false\n"
                    }
                ],
                "command": {"linux": [
                    "sudo apt install nginx -y 2>&1 >/dev/null",
                    "systemctl enable nginx 2>&1 >/dev/null",
                    "systemctl start nginx 2>&1 >/dev/null"
                ]},
                "retryCount": 2,
                "failureBehavior": {
                    "action": "retryThenFail",
                    "retryBackoffStrategy": {
                        "type": "linear",
                        "delaySeconds": 1,
                        "arguments": []
                    }
                },
                "limits": {},
                "name": "install nginx conditionally"
            },
            {
                "interpreter": {
                  "skill": {
                    "minVersion": "1.0.0"
                  },
                  "name": "chef-platform/shell-interpreter"
                },
                "command": {"linux": [
                    "curl -s http://localhost:80 | grep 'hello world!' >/dev/null && echo true || echo false"
                ]},
                "inputs": {},
                "expectedInputs": {},
                "outputFieldRules": {
                    "EXPECTED_PAGE_FOUND": {
                        "source": "stdout",
                        "sourceType": "output",
                        "extractMethod": "content",
                        "expression": "",
                        "required": true,
                        "sensitive": false
                    }
                },
                "retryCount": 2,
                "failureBehavior": {
                    "action": "retryThenFail",
                    "retryBackoffStrategy": {
                        "type": "linear",
                        "delaySeconds": 1,
                        "arguments": []
                    }
                },
                "limits": {},
                "conditions": [],
                "name": "check if nginx is configured"
            },
            {
                "interpreter": {
                  "skill": {
                    "minVersion": "1.0.0"
                  },
                  "name": "chef-platform/shell-interpreter"
                },
                "inputs": {},
                "expectedInputs": {
                    "EXPECTED_PAGE_FOUND": {
                        "type": "string",
                        "sensitive": false,
                        "required": true,
                        "default": ""
                    }
                },
                "outputFieldRules": {},
                "conditions": [
                    {
                        "inputName": "EXPECTED_PAGE_FOUND",
                        "operator": "eq",
                        "value": "false\n"
                    }
                ],
                "command": {"linux": [
                    "echo '<html><body><h1>hello world!</h1></body></html>' | sudo tee /var/www/html/index.nginx-debian.html > /dev/null"
                ]},
                "retryCount": 2,
                "failureBehavior": {
                    "action": "retryThenFail",
                    "retryBackoffStrategy": {
                        "type": "linear",
                        "delaySeconds": 1,
                        "arguments": []
                    }
                },
                "limits": {},
                "name": "configure nginx if not already"
            },
            {
                "interpreter": {
                  "skill": {
                    "minVersion": "1.0.0"
                  },
                  "name": "chef-platform/shell-interpreter"
                },
                "command": {"linux": [
                    "curl -s http://localhost:80 | grep 'hello world!'"
                ]},
                "inputs": {},
                "expectedInputs": {},
                "outputFieldRules": {},
                "conditions": [],
                "retryCount": 2,
                "failureBehavior": {
                    "action": "retryThenFail",
                    "retryBackoffStrategy": {
                        "type": "linear",
                        "delaySeconds": 1,
                        "arguments": []
                    }
                },
                "limits": {},
                "name": "check if nginx is properly configured"
            }
        ]
    }
}
EOF

    chef-courier-cli scheduler jobs add-job --body-file $inFile | tee $outFile 2>&1
    jobId="$(cat $outFile | jq -r '.item | .id')"
fi

echo ''
echo 'jobName="'$jobName'"' >>  $vars    
echo 'jobId="'$jId'"' >>  $vars    

# END OF SCRIPT


