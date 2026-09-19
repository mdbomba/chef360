#!/usr/bin/env bash

# Historical lab example for registering Chef 360 CLI profiles.
#
# register-device creates a local authentication profile; it does not create or
# grant tenant or organization administrator roles. During browser
# authorization, sign in as a user who already has the intended role and select
# the appropriate tenant and organization context.
#
# The endpoint and profile names below are environment-specific. Use --insecure
# only in an isolated lab; prefer --cafile with a trusted CA. For supported,
# parameterized use, run scripts/chef360/register-chef360-workstation.sh.

echo 'This historical example registers workstation profiles for existing tenant and organization roles.'
read -r -p 'Press Ctrl-c to terminate, or Enter to continue: '

echo 'Register a local profile for an existing tenant administrator role'
echo 'Open the displayed link and authorize as the intended tenant administrator'
chef-platform-auth-cli register-device --device-name chef-workstation --profile-name tenant --url https://courier.kemptech.biz:31000 --insecure

echo 'Verify the active role associated with the tenant profile'
chef-platform-auth-cli user-account self get-role --profile tenant

echo 'Register a local profile for an existing organization administrator role'
echo 'Open the displayed link and authorize as the intended organization administrator'
chef-platform-auth-cli register-device --device-name chef-workstation --profile-name chef --url https://courier.kemptech.biz:31000 --insecure

echo 'Verify the active role associated with the organization profile'
chef-platform-auth-cli user-account self get-role --profile chef

echo 'Set the organization administrator profile as default'
chef-platform-auth-cli set-default-profile chef

echo 'Display all local profile names'
chef-platform-auth-cli list-profile-names
