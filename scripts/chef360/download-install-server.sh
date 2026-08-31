#!/bin/bash

# SCRIPT TO DOWNLOAD AND INSTALL CHEF 360 PLATFORM 1.7.3
#
# PLAN
# Plan hostname, domain name, and deployment architecture (single-node, hyperconverged non-HA)
# For a customer retaining an existing single-node, non-HA Chef Infra availability model,
# this is the closest matching Chef 360 topology. Size Chef 360 independently for its workload.
# Request certificate in Base64-encoded PEM format
# Request corresponding private key in unencrypted Base64-encoded PEM format
# Request certificate-issuing hierarchy chain file in Base64-encoded PEM format
# Confirm the customer has an active Chef Compliance managed-endpoint license.
# Request the separate Chef 360 download authorization code from Progress.
# The downloaded archive contains the authorization-specific license.yaml used to license Chef 360.
#
# BUILD LINUX HOST
# Create a new Linux host using a recent distribution (for example, Ubuntu 24.04 or Rocky 10)
# Assign VM resources
     # 16 cores
     # 32G RAM
# Fully Provisioned Drive partitioned as:
# /boot (1G)
# / (100G)
# /var/lib (200-500G)
# Prefer ext4 for /var/lib on KVM; XFS with ftype=1 is also acceptable
# Do not mount /var/lib with the noexec option
# Disable host swap; do not configure a swap partition or swap file on / or /var/lib
#    $ sudo swapoff -a
#    $ swapon --show=NAME,TYPE,SIZE,USED,PRIO
#    $ systemctl list-units --type=swap --state=active
# Setup admin account to sudo without auth.
#    $ sudo su
#    # echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
#    # chmod 440 /etc/sudoers.d/admin
#    # visudo -cf /etc/sudoers.d/admin
# Assign host a fqdn
#    # hostnamectl set-hostname [hostname.domain]
# Add host name to /etc/hosts
#    # echo "[ipaddress] [hostname.domain] [hostname]"
# Ensure the network time service is working
#    #
# Ensure IP is statically assigned (do not use dhcp assigned IP address)
#    {Methods vary. for netplan managed hosts, look in /etc/netplan for numbered files and see if dhcp=no}
# Ensure DNS or /etc/hosts file is properly configured with chef360 ip and fqdn
# Test IP stack by pinging router and external known host
#
# update host
    # $ sudo apt update && sudo apt upgrade -y
# ensure openssh is installed
    # $ sudo apt install openssh-server -y
#
# DOWNLOAD CHEF 360 PLATFORM 1.7.3
read -r -p "Download the air-gapped package? [y/N]: " AIRGAP
DOWNLOAD_URL="https://appservice.chef360.chef.io/embedded/chef-360/stable/1.7.3"
INSTALL_OPTIONS=()
if [[ "$AIRGAP" =~ ^[Yy]$ ]]; then
    DOWNLOAD_URL="${DOWNLOAD_URL}?airgap=true"
    INSTALL_OPTIONS=(--airgap-bundle chef-360.airgap)
fi

read -r -s -p "Enter your Chef 360 authorization code: " AUTH
printf '\n'
curl -f "$DOWNLOAD_URL" -H "Authorization: $AUTH" -o chef-360-1.7.3.tgz
unset AUTH
unset AIRGAP DOWNLOAD_URL
tar -xvzf chef-360-1.7.3.tgz
test -s license.yaml || { printf '%s\n' "The downloaded package did not contain a usable license.yaml." >&2; exit 1; }

# INSTALL CHEF 360 PLATFORM
# This license.yaml came from the downloaded package; do not substitute another Chef product license.
sudo ./chef-360 install --license license.yaml "${INSTALL_OPTIONS[@]}"
unset INSTALL_OPTIONS

# AFTER INSTALL, USE THE COMPLETE "Admin Console accessible at:" LINK RETURNED BY THE INSTALLER
# If its host is inaccessible, replace only the host with the public FQDN and retain port 30000 and the path.
# During first connection, you will have 1 chance to assign certificates to the Admin Console (https://FQDN:30000/)
# Once connected to the Admin Console (Replicated-based interface), configure Chef 360 Platform.
# During configuration, use Mailpit or your organization's SMTP service (Mailpit is for evaluation and testing).
# If using Mailpit, use HTTP rather than HTTPS and connect to http://ipaddress:31101/.
# After you apply the config, you will get an email with a one-time password for the Apps Console (https://FQDN:31000/)
# Once you can sign in to the Chef 360 Apps Console, you have completed basic platform setup.
# On the Admin Console Dashboard, verify and record that the current application version is 1.7.3.
#
# Chef 360 includes
#    node management (primarily for courier service)
#    courier job runner
#    Declarative State Management (DSM) service
#    Tenant Admin
#    Org Admin
#    Download service (for chef360 CLI components)
