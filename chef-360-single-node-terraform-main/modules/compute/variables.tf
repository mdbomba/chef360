variable "name_prefix" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  type = bool
}

variable "root_volume_type" {
  type = string
}

variable "user_data_template_path" {
  type = string
}

variable "user_data_extra" {
  type = string
}

variable "instances" {
  type = map(object({
    hostname         = string
    role             = string
    instance_type    = string
    root_volume_size = number
    subnet_index     = number
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "ssh_private_key_path" {
  description = "Local path to the .pem private key used to SSH into Chef 360 nodes."
  type        = string
  default     = "/Users/abprusty/.aws/Abinash_us_east_1.pem"
}

variable "admin_console_password" {
  description = "Admin Console password set during Chef 360 installation."
  type        = string
  sensitive   = true
}
