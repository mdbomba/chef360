# Start of Settings
vars="./chef360.vars"
source $vars

node='10.0.0.9'
user='chef'
keyfile='/home/chef/.ssh/id_rsa'

key=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $keyfile)

if ping -c 2 $node >/dev/null 2>&1 ; then
  echo "Connectivity validated to $node"
else
  echo "Conectivity failed to $node. EXITING SCRIPT"
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
chef-node-management-cli enrollment enroll-node --body-format json --body-file enroll-linux.json | tee ./enroll-linux.out

    id="$(cat ./enroll-linux.out | jq .item | jq .id | tr -d '"' )"

    nodeId="$(cat ./enroll-linux.out | jq .item | jq .nodeId | tr -d '"' )"
    
    echo 'node_name="'$node'"' >>  $vars
    echo 'node_cohortId="'$cohortId'"' >>  $vars
    echo 'node_id="'$id'"' >>  $vars
    echo 'node_nodeId="'$nodeId'"' >>  $vars


