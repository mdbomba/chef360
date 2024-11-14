# Start of Settings
vars="./chef360.vars"
source $vars

node='node3.kemptech.biz'
nodeIp='10.0.0.9'
user='chef'
keyfile='/home/chef/.ssh/id_rsa'
cohortId=$(chef-node-management-cli management cohort find-all-cohorts | jq -r --arg name "$cohortName" '.items | .[] | select(.name==$name) | .id')
key=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $keyfile)

if ping -c 2 $node >/dev/null 2>&1 ; then 
  echo '' >/dev/null
else
  echo "Conectivity failed to $nodeIp. EXITING SCRIPT"
  exit
fi

# create enroll-linux.json file
echo '{
    "cohortId": "'"$cohortId"'",
    "url": "'"$node"'",
    "sshCredentials": {
        "username": "'"$user"'",
        "key": "'"$key"'",
        "port": 22
    }
}' > ./enroll-linux.json

# enroll node
chef-node-management-cli enrollment enroll-node --body-format json --body-file enroll-linux.json | tee ./enroll-linux.out >/dev/null

enrollmentId="$(cat ./enroll-linux.out | jq .item | jq .id | tr -d '"' )"
node=$(ssh $nodeIp hostname)
nodeId=$(ssh $nodeIp 'cat /hab/svc/node-management-agent/data/node_guid')
   
echo 'cohortId="'$cohortId'"'            >>  $vars
echo 'node="'$node'"'                    >>  $vars
echo 'nodeIp="'$nodeIp'"'                >>  $vars
echo 'nodeId="'$nodeId'"'                >>  $vars
echo 'sysId="'$sysId'"'                  >>  $vars
echo 'rollId="'$rollId'"'                >>  $vars
echo 'enrollmentId="'$enrollmentId'"'    >>  $vars


 sysId=$(chef-platform-auth-cli node-account node get-nodeByRef --refId $nodeId --profile $orgAdmin --format json | jq -r '.item.id')
roleId=$(chef-platform-auth-cli node-account node get-nodeByRef --refId $nodeId --profile $orgAdmin --format json | jq -r '.item.roles[] | select(.name == "courier-runner") | .id')

echo "cohortId       = $cohortId"
echo "node           = $node"
echo "nodeIp         = $nodeIp"
echo "nodeId         = $nodeId"
echo "sysId          = $sysId"
echo "roleId         = $roleId"
echo "enrollmentId   = $enrollmentId"

CREDS=$(chef-platform-auth-cli node-account node update-credentials --nodeId $sysId --roleId $roleId --profile $orgAdmin --format json)

CERT=$(echo $CREDS | jq -r '.item.privateCert')

printf "%s" "$CERT" | sudo tee ./courier-runner-key.pem >/dev/null

ssh $nodeIp 'sudo hab svc stop chef-platform/courier-runner'  > /dev/null 2<&1
scp ./courier-runner-key.pem $user@$nodeIp:/home/$user/ > /dev/null 2<&1
ssh $nodeIp 'sudo mv /hab/svc/node-management-agent/data/courier-runner-key.pem  /hab/svc/node-management-agent/data/courier-runner-key.bak' > /dev/null 2<&1
ssh $nodeIp 'sudo mv ./courier-runner-key.pem  /hab/svc/node-management-agent/data/courier-runner-key.pem' > /dev/null 2<&1
ssh $nodeIp 'sudo hab svc start chef-platform/courier-runner'  > /dev/null 2<&1


