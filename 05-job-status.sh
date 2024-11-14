# JOB RUN DETAILS SCRIPT v1.0
#
# Reads input from 08-create-job-simple-output.json
# Parses job instance id
#
# Use the job run ID to get a list of steps executed during a job run:
#
#
vars="./chef360.vars"
source $vars
jobStatus='unk'

# CLEAN OUT OLD JOB NAMES AND IDS FROM VARS FILE
grep -v 'instanceId' $vars > $vars.1
grep -v 'jobStatus' $vars.1 > $vars.2
grep -v 'runId' $vars.1 > $vars
rm -rf $vars.*

jobStatus="$(chef-courier-cli state instance list-all --job-id $jobId  | jq -r '.items | .[] |.status' )"
instanceId="$(chef-courier-cli state instance list-all --job-id $jobId  | jq -r ' .items | .[] | .id' )"
runId="$(chef-courier-cli state instance list-instance-runs --instanceId $instanceId | jq .items | jq '.[]' | jq .runId)"


echo "instanceId=$instanceId" >> $vars
echo "jobStatus=$jobStatus" >> $vars
echo "runId=$runId" >> $vars
echo ''
echo "OVERALL JOB STATUS UPDATED EVERY 15 SECONDS"   
echo "Job Name   = $jobName"
echo "Job ID     = $jobId"
echo "Job Status = $jobStatus"
echo "Job Run ID = $runId"
while [ ! "x$jobStatus" = "xsuccess" ] && [ ! "x$jobStatus" = "xfailure" ]
do 
    sleep 15
    jobStatus="$(chef-courier-cli state instance list-all --job-id $jobId  | jq .items | jq '.[]' | jq .status | tr -d '"' )" 
    echo "Job Status - $jobStatus"
done
    echo "JOB INSTANCE DETAILS"
    
    chef-courier-cli state run list-steps --runId $runId | jq -rM '.items | .[] ' 


# END OF SCRIPT
