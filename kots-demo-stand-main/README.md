# Courier Demo

Demo environment for provisioning AWS infrastructure and bootstrapping a Chef 360 / Courier setup.

## What this repo does

1. Provisions networking and EC2 instances with Terraform.
2. Brings up a Chef 360 server and client nodes ready to be bootstrapped

## Repository layout

```text
terraform/aws/
  modules/network/      # VPC/subnet/DNS/security primitives
  modules/chef360/      # Chef 360 and client instances + cloud-init templates
  main.tf               # root module wiring
  variables.tf
  terraform.tfvars.example
```

## Prerequisites

- Terraform `1.9.8`
- AWS credentials/profile with permissions to create VPC, EC2, security groups, and DNS records

## Quick start

### 1) Provision infrastructure

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your AWS + tenant values
terraform init
terraform plan
terraform apply
```

## Notes and conventions

- `terraform.tfvars`, `.tfstate`, and local `.terraform/` artifacts are ignored by git.
- This demo uses a `kots.yml` file to configure the Chef 360 server. It may need updates when new Chef 360 releases change installer-generated settings.
- Known issue: Chef 360 can finish installing while the Admin Console shows the deploy as failed. Workaround: once the admin portal is up, log in and click **Deploy**; the deployment should then complete successfully.

### Refreshing `kots.yml` for new Chef 360 releases

1. In the Chef 360 cloud-init script, comment out the last line so the installer is not auto-run.
2. Launch the instance and run the Chef 360 installer manually.
3. Complete manual configuration of Chef 360.
4. In the Admin Console, open **View files** and download the updated configuration from `upstream > userdata > config.yaml`.
5. Use that updated config to refresh this repo's `kots.yml`.

## Common Terraform commands

```bash
cd terraform/aws
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform destroy
```
