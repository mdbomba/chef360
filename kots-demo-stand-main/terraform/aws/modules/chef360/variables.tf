variable "tags" {
    description    = "Tags to use for resources"
    type                = map(string)
    default            = {}
}

variable "vpc_id" {
    description    = "ID of primary vpc"
    type                = string
}

variable "subnet_id" {
    description    = "ID of primary subnet"
    type                = string
}

variable "aws_key_pair_name" {
    description = "Name of AWS key pair"
}

variable "authorization_code" {
    description = "Auth code for Chef 360"
    type = string
  
}

variable "tenant_subdomain" {
    description = "subdomain for Chef 360"
    type = string
  
}

variable "tenant_tld" {
    description = "top-level domain for Chef 360"
    type = string
}

variable "console_password" {
    description = "Admin console password for Chef 360"
    type = string
}

variable "admin_first_name" {
    description = "Admin first name for Chef 360"
    type = string
}

variable "admin_last_name" {
    description = "Admin last name for Chef 360"
    type = string
}

variable "admin_email" {
    description = "Admin email for Chef 360"
    type = string
}

variable "tenant_name" {
    description = "Tenant name for Chef 360"
    type = string
}

variable "org_unit_name" {
    description = "Org unit name for Chef 360"
    type = string
}