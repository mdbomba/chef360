#cloud-config

write_files:
  - content: |
      ${base64encode(kots)}
    encoding: b64
    owner: 'root:root'
    path: '/home/ubuntu/kots.yaml'
    permissions: '0755'

runcmd:
  - hostname "${tenant_subdomain}.${tenant_tld}"
  - chown ubuntu:ubuntu /home/ubuntu -R
  - chmod 700 /home/ubuntu
  - chmod 700 /home/ubuntu/.ssh
  - [ curl,  https://replicated.app/embedded/chef-360/stable,  -H,  "Authorization: ${authorization_code}",  -o,  /home/ubuntu/chef-360.tgz ]
  - [tar, -x, -v, -z, -f, /home/ubuntu/chef-360.tgz, -C, /home/ubuntu ]
  - [ /home/ubuntu/chef-360,  install,  --license,  /home/ubuntu/license.yaml, --no-prompt, --admin-console-password, "${console_password}", --config-values, /home/ubuntu/kots.yaml, --ignore-host-preflights ]