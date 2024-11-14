vars="./chef360.vars"
source $vars
file="$./list-all-jobs.out"
filename='./job-nginx.json'
nodeip='10.0.0.9'

jobName='100-courier-lab-nginx-6'
jobDescription='Rolling Jobs'
nodeId=$node_nodeId
pwd=$(pwd)

# CLEAN OUT OLD JOB NAMES AND IDS FROM VARS FILE
grep -v 'jobName' $vars > $vars.1
grep -v 'jobId' $vars.1 > $vars
rm -rf $vars.1

chef-courier-cli scheduler jobs list-jobs | jq .items | jq '.[]' | jq .name | tr -d '"' > $file
if grep "$jobName" $file ; then 
    echo "Job with same name ($jobName) already exists. Exiting script"
    exit
fi

cat <<EOF > $filename
{
  "name": "$jobName",
  "description": "$jobDescription",
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
                  "$nodeip"
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

clear
cat $filename

read -p 'Press enter to continue. Crtp-C to cancel' yn


echo "REGISTERING JOB NAMED - $jobName" 
chef-courier-cli scheduler jobs add-job --body-file $filename | tee $filename.out
jobId="$(cat $filename.out | jq .item | jq .id | tr -d '"' )"
echo 'jobName="'$jobName'"' >>  $vars    
echo 'jobId="'$jobId'"' >>  $vars    

echo "jobName and jobId stored in $vars"
echo $vars







# END OF SCRIPT


