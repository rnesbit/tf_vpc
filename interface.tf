# tf_vpc/interface.tf

variable "environment" {
  type = "string"
  description = "name of the environment."
}

variable "region" {
  type = "string"
}

variable "cidr" {
  type = "string"
  description = "The CIDR of the VPC."
 }

variable "enable_dns_hostnames" {
   default     = true
   description = "Should be true if you want to use private DNS within the VPC"
}

variable "enable_dns_support" {
   default     = true
   description = "Should be true if you want to use private DNS within the VPC"
}

variable "azs" {
  default = ["us-west-2a", "us-west-2b", "us-west-2c"]
  description = "availability zones"
}

variable "public_subnets" {
  default = ["10.0.0.0/25", "10.0.0.128/25", "10.0.1.0/25"]
  description = "the public subnets"
 }

variable "private_subnets" {
  default = ["10.0.2.0/23", "10.0.4.0/23", "10.0.6.0/23"]
  description = "the private subnets"
}

variable "map_public_ip_on_launch" {
  default = true
}

# hosts

variable "key_name" {
  type = "string"
}

# bastion host

variable "bastion_ami" {
  type = "map"
}

variable "bastion_instance_type" {
  type = "string"
}

# terraform host

variable "terraform_ami" {
  type = "map"
}

variable "terraform_instance_type" {
  type = "string"
}

# spinnaker host

variable "spinnaker_ami" {
  type = "map"
}

variable "spinnaker_instance_type" {
  type = "string"
}

# jenkins host

variable "jenkins_ami" {
  type = "map"
}

variable "jenkins_instance_type" {
  type = "string"
}
