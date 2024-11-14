vars="./chef360.vars"
source $vars

jobName='lab job simple sleep 3'
jobDescription='Simple job to put a node to sleep for 10 seconds'
nodeId=$node_nodeId
pwd=$(pwd)
file="$pwd/job-list.out"

chef-courier-cli scheduler jobs list-jobs | jq .items | jq '.[]' | jq .name | tr -d '"' > $file
if grep "$jobName" $file ; then 
    echo "Job with same name ($jobName) already exists. Exiting script"
    exit
fi

echo '{
  "name": "'"$jobName"'",
  "description": "'"$jobDescription"'",
  "scheduleRule": "immediate",
  "exceptionRules": [],
  "target": {
    "executionType": "sequential",
    "groups":[
      {
        "timeoutSeconds": 240,
        "batchSize": {},
        "distributionMethod": "batching",
        "successCriteria": [
          {
            "numRuns": { "type": "percent", "value": 100 },
            "status": "success"
          }
        ],
        "nodeListType":"nodes",
        "nodeIdentifiers":[
          "'"$nodeId"'"
        ]
      }
    ]
  },
  "actions": {
    "accessMode": "agent",
    "steps":
    [
      {
        "name": "step to sleep",
        "interpreter": {
          "skill": {
            "minVersion": "1.0.0"
          },
          "name": "chef-platform/shell-interpreter"
        },
        "command": {
          "linux": [
            "sleep 10"
          ],
          "windows": [
            "timeout 10"
          ]
        },
        "inputs": {},
        "expectedInputs": { },
        "outputFieldRules": {},
        "retryCount": 2,
        "failureBehavior": {
          "action": "retryThenFail",
          "retryBackoffStrategy": {
            "type": "linear",
            "delaySeconds": 1,
            "arguments": [1,3,5]
          }
        },
        "limits": {},
        "conditions": []
      }
    ]
  }
}' > ./lab-job-1.json


echo "REGISTERING JOB NAMED - %jobName" 
chef-courier-cli scheduler jobs add-job --body-file ./lab-job-1.json | tee ./lab-job-1.out
jobId="$(cat ./lab-job-1.out | jq .item | jq .id | tr -d '"' )"
echo 'jobName="'$jobName'"' >>  $vars    
echo 'jobId="'$jobId'"' >>  $vars    

echo "jobName and jobId stored in $vars"
echo $vars







# END OF SCRIPT


