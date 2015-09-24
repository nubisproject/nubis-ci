variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "release" {}

variable "environment" {
  description = "Name of the environment this deployment is for"
  default = "sandbox"
}

variable "nubis_domain" {
  description = "Top-level Nubis domain for this environemnt"
  default = "nubis.allizom.org"
}

variable "ami" {
  default = "ami-85e49be0"
  description = "Nubis CI AMI to launch"
}

variable "region" {
  default = "us-east-1"
  description = "The region of AWS, for AMI lookups and where to launch"
}

variable "release" {
  description = "Release number of the architecture"
  default = 0
}

variable "build" {
  description = "Build number of the architecture"
  default = 91
}

variable "admin_password" {
  description = "Password to access CI"
}

variable "git_repo" {
  description = "URL to git repo to build"
  default = "https://github.com/mozilla/nubis-ci.git"
}

variable "project" {
  description = "Name of the Nubis project"
  default = "ci"
}

variable "key_name" {
  description = "SSH key name in your AWS account for AWS instances."
}

variable "domain" {
  description = "Name of the domain for that zone"
}

variable "zone_id" {
  description = "ID of the zone for the project"
}

variable "elb_subnet_id" {
  default = ""
}

variable "vpc_id" {
  default = ""
}

variable "internet_security_group_id" {
  description = "ID of that SG"
}

variable "shared_services_security_group_id" {
  description = "ID of that SG"
}

variable "ssh_security_group_id" {
  description = "ID of that SG"
}

variable "public_subnets" {
  description = "Public Subnets IDs, comma-separated"
}

variable "private_subnets" {
  description = "Private Subnets IDs, comma-separated"
}

variable "account_name" {
  description = "Name of the AWS account"
}

variable "s3_bucket_name" {
  description = "Name of the S3 Bucket to store artifacts in"
}

variable "email" {
  description = "e-mail to send build notifications to"
  default = "gozer@mozilla.com"
}
