variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "iam_instance_profile" {}

variable "release" {}

variable "environment" {
  description = "Name of the environment this deployment is for"
  default = "sandbox"
}

variable "consul" {
  description = "URL to Consul"
  default = "127.0.0.1"
}

variable "consul_secret" {
  description = "Security shared secret for consul membership (consul keygen)"
}

variable "consul_ssl_cert" {
  description = "SSL Certificate file"
}

variable "consul_ssl_key" {
  description = "SSL Key file"
}

variable "ami" {
  default = "ami-08dcf860"
  description = "Nubis CI AMI to launch"
}

variable "region" {
  default = "us-east-1"
  description = "The region of AWS, for AMI lookups and where to launch"
}

variable "release" {
  description = "Release number of the architecture"
}

variable "build" {
  description = "Build number of the architecture"
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

variable "zone_id" {
  description = "ID of the zone for the project"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to store artifacts into"
  default = "nubis-ci"
}
