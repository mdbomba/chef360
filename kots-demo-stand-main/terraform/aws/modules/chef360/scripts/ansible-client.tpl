#cloud-config

write_files:
  - content: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtz
      c2gtZWQyNTUxOQAAACC350Wj6ZpfR9K8Yf52vJddFBiHaJR3sVGV0CxSFkampwAA
      AIhrDuVVaw7lVQAAAAtzc2gtZWQyNTUxOQAAACC350Wj6ZpfR9K8Yf52vJddFBiH
      aJR3sVGV0CxSFkampwAAAEAwUQIBATAFBgMrZXAEIgQgpfabt/EsUbZ5FAS6A6eL
      t7fnRaPpml9H0rxh/na8l10UGIdolHexUZXQLFIWRqanAAAAAAECAwQF
      -----END OPENSSH PRIVATE KEY-----
    owner: root:root
    path: /srv/ansible/dslanec_client.pem
    permissions: '0600'
  - content: |
      [defaults]
      inventory=/srv/ansible/inventory.yaml
      interpreter_python=auto_silent
    owner: root:root
    path: /srv/ansible/ansible.cfg
    permissions: '0755'
  - content: |
      webservers:
        hosts:
          webserver02:
            ansible_host: 10.0.1.20
        vars:
          ansible_user: ubuntu
          ansible_ssh_private_key_file: /srv/ansible/dslanec_client.pem
    owner: root:root
    path: /srv/ansible/inventory.yaml
    permissions: '0755'
  - content: |
      - name: Bootstrap playbook
        hosts: all
        gather_facts: false
        tasks:
          - name: Write the {{ ansible_host }} host key to known hosts
            connection: local
            ansible.builtin.shell: "ssh-keyscan -H {{ ansible_host }} >> ~/.ssh/known_hosts"
    owner: root:root
    path: /srv/ansible/playbooks/bootstrap.yaml
    permissions: '0755'

runcmd:
  - apt update
  - apt install ansible -y
  - cd /srv/ansible
  - ansible-playbook playbooks/bootstrap.yaml