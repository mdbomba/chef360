
admin='tenant'
node_admin='chef'
node_name='node3'

NODE=$(ssh $node_name 'cat /hab/svc/node-management-agent/data/node_guid')
echo "Node = $NODE"

SYS_ID=$(chef-platform-auth-cli node-account node get-nodeByRef --refId $NODE --profile $admin --format json | jq -r '.item.id')
ROLE_ID=$(chef-platform-auth-cli node-account node get-nodeByRef --refId $NODE --profile $admin --format json | jq -r '.item.roles[] | select(.name == "courier-runner") | .id')
echo "SYS_ID = $SYS_ID"
echo "ROLE_ID = $ROLE_ID"

CREDS=$(chef-platform-auth-cli node-account node update-credentials --nodeId $SYS_ID --roleId $ROLE_ID --profile $admin --format json)
echo "CREDS"
echo $CREDS | jq

CERT=$(echo $CREDS | jq -r '.item.privateCert')
echo "CERT"
echo ""
echo $CERT

printf "%s" "$CERT" | sudo tee ./courier-runner-key.pem

ssh $node_name 'sudo hab svc stop chef-platform/courier-runner' 
scp ./courier-runner-key.pem $node_admin@$node_name:/home/$node_admin/
ssh $node_name 'sudo mv /hab/svc/node-management-agent/data/courier-runner-key.pem  /hab/svc/node-management-agent/data/courier-runner-key.bak'
ssh $node_name 'sudo mv ./courier-runner-key.pem  /hab/svc/node-management-agent/data/courier-runner-key.pem'
ssh $node_name 'sudo hab svc start chef-platform/courier-runner' 




 



