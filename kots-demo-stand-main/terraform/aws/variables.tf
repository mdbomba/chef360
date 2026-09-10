////////////////////////////////
// AWS Connection

variable "aws_region" {
  default="us-east-1"
  description = "aws_region is the AWS region in which we will build instances"
}

variable "aws_profile" {
  default="default"
  description = "aws_profile is the profile from your credentials file which we will use to authenticate to the AWS API."
}

variable "aws_credentials_file" {
  default=["~/.aws/credentials"]
  description = "aws_credentials_file is the file on your local disk from which we will obtain your AWS API credentials."
}



variable "aws_key_pair_file" {
  description = "Location of AWS key for ec2"
}

variable "aws_key_pair_name" {
  description = "Name of the AWS keypair"
}


////////////////////////////////
// Object Tags

variable "tag_customer" {
  description = "tag_customer is the customer tag which will be added to AWS"
}

variable "tag_project" {
  description = "tag_project is the project tag which will be added to AWS"
}

variable "tag_name" {
  description = "tag_name is the name tag which will be added to AWS"
}

variable "tag_dept" {
  description = "tag_dept is the department tag which will be added to AWS"
}

variable "tag_contact" {
  description = "tag_contact is the contact tag which will be added to AWS"
}

variable "tag_application" {
  description = "tag_application is the application tag which will be added to AWS"
}

variable "tag_ttl" {
  default = 4
}

////////////////////////////////
// Chef 360

variable "authorization_code" {
  description = "Auth code for Chef 360"
}

variable "tenant_subdomain" {
  description = "subdomain for Chef 360"
}

variable "tenant_tld" {
  description = "top-level domain for Chef 360"
}

variable "console_password" {
  description = "Admin console password for Chef 360"
}

variable "admin_first_name" {
  description = "Admin first name for Chef 360"
}

variable "admin_last_name" {
  description = "Admin last name for Chef 360"
}

variable "admin_email" {
  description = "Admin email for Chef 360"
}

variable "tenant_name" {
  description = "Tenant name for Chef 360"
}

variable "org_unit_name" {
  description = "Organization unit name for Chef 360"
}