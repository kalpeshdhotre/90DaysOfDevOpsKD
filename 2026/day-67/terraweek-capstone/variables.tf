variable "project_name" {
  type    = string
  default = "terraweek"
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "ingress_ports" {
  type    = list(number)
  default = [22, 80]
}

variable "ami_id" {
  type        = string
  description = "Amazon Linux 2023 AMI for ap-south-1"
  default     = "ami-0f918f7e67a3323f0" # verify current AMI before apply
}
