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


instanceId="$(chef-courier-cli state instance list-all --job-id $jobId  | jq .items | jq '.[]' | jq .id )"
jobStatus="$(chef-courier-cli state instance list-all --job-id $jobId  | jq .items | jq '.[]' | jq .status | tr -d '"' )"
runId="$(chef-courier-cli state instance list-instance-runs --instanceId $instanceId | jq .items | jq '.[]' | jq .runId)"
chef-courier-cli state run list-steps --runId $runId

echo "instanceId=$instanceId" >> $vars
echo "jobStatus=$jobStatus" >> $vars
echo "runId=$runId" >> $vars

echo "Job Status - $jobStatus"
while [ ! "x$jobStatus" = "xsuccess" ] && [ ! "x$jobStatus" = "xfailure" ]
do 
    echo ''
    echo "OVERALL JOB STATUS UPDATED EVERY 10 SECONDS"    sleep 10
    jobStatus="$(chef-courier-cli state instance list-all --job-id $jobId  | jq .items | jq '.[]' | jq .status | tr -d '"' )" 
    echo "Job Status - $jobStatus"
done
    echo ""
    echo "JOB INSTANCE DETAILS"
    
    chef-courier-cli state run list-steps --runId $runId


# END OF SCRIPT
