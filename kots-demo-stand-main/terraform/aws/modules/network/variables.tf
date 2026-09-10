variable "tags" {
    description = "Tags to use for resources"
    type = map(string)
    default = {}
}

variable "aws_region" {
    description = "Region for AZ"
    type = string
}