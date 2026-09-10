variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_cidr_blocks" {
  type = list(string)
}

variable "admin_cidr_blocks" {
  type = list(string)
}

variable "multi_node" {
  type = bool
}

variable "enable_mailpit_port" {
  type = bool
}

variable "tags" {
  type    = map(string)
  default = {}
}
