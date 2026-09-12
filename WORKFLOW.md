Workflow for this repo

Purpose of this repo is to automate the installation and if possible the configuration of a chef360 hyperconverged nonHA single node system.

Downloading this repo from https://github.com/mdbomba/chef360. All user will have read access (public repo) but only mike.bomba@progress.com will have write access to this repo. 

The user would copy this repo locally and then start an AI Agent and point it at this repo. 

The user would then indicate an interest in installing Chef360. 

To install Chef360, there needs to be a VM with the proper configuration available. It it is not already available, then it needs to be created using one of 2 approaches (1) build it using and iso or (2) use a clone image to create it. 

Once the VM is available, it needs to be checked to ensure it meets minimum standards which includes:
  -  16 VCPU
  -  32768 MB RAM
  -  DISK1 with 
      -  1G /boot partition
      -  100G / partition (ext4)
  -  DISK2
      -  250G /var/lib/embedded-cluster (XFS) (fstype=1) partition 
  -  swap disabled and removed from /etc/fstab
  -  admin user able to invoke sudo without password prompt
  -  .ssh keys to allow VM Host to connect to VM without password
  -  (e.g.  sudo echo "chef ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/chef && sudo chmod 440 /etc/sudoers.d/chef)
  -  openssh-server installed
  -  IP set static to desired values (e.g.  10.0.0.20/24)
  -  DNS set to host NAT IP address  (e.g. 10.0.0.1)
  -  Router set to Hypervisor value  (e.g. 10.0.0.2) 
  -  DNS can properly resolve an IP (e.g. ping google.com)

After VM is validated, then chef360 is installed
  -  copy chef-360 and license.yaml to admin user home folder or some other working folder
  -  copy cert/key/chain files to same working directory
  -  prepare (if possible) a kots-config.yaml file holding setup parameters
  -  install using chef-360 install command with appropriate arguments to include cert and key arguments
  -  if kots-config.yaml was not used, the user will need to enter the password for the admin console
  -  if kots-config.yaml was used, this value is passed in the command line options to the installer (chef-360)
  -  watch the pods as they deploy (sudo k0s kubectl get pods -n chef-360) until all are Running or Completed
     ( e.g.  sudo k0s kubectl get pods -n chef-360 | grep -v Running | grep -v Completed) this will display pods still starting. 
  -  once all pods are depolyed:
    -  if kots-config.yaml was not used:
      -  user need to connect to https://IP:30000 and configure/deploy settings
      -  user need to connect to http://IP:321101 and wait for email and follow instructions to set App dashboard password
      -  user need to then connect to https://FQDN:31000 and sign into chef-360 APP Dashboard
    -  if kots-config.yaml was used:
      -  user will be prompted when it is time to connect to http://IP:31101 to read email and follow instructions to set password
      -  user will then connect to https://FQDN:31000 and sign in to APP dashboard.
  -  NOTE: If user waits more than 5 minutes to open email and set password, user should request a new password using link at bottom of set password page

After chef360 is installed
  -  the user should ask the AI agent to cleanup (this removes all project specific files and secrets)
  -  the folders typically used to store project specific data are in the .gitignore file and should be safe if the user wants to use their github to protect the repo. 




