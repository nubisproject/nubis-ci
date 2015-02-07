variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "iam_instance_profile" {}

variable "release" {}

variable "consul" {
  description = "URL to Consul"
  default = "127.0.0.1"
}

variable "secret" {
  description = "Security shared secret for consul membership (consul keygen)"
}

variable "region" {
  default = "us-west-2"
  description = "The region of AWS, for AMI lookups and where to launch"
}

variable "release" {
  description = "Release number of the architecture"
}

variable "build" {
  description = "Build number of the architecture"
}

variable "ci_release" {
  description = "Release number of the CI"
}

variable "ci_build" {
  description = "Build number of the CI"
}

variable "git_repo" {
  description = "URL to git repo to build"
  default = "https://github.com/mozilla/nubis-ci.git"
}

variable "project" {
  description = "Name of the Nubis project"
  default = "CI"
}

variable "key_name" {
  description = "SSH key name in your AWS account for AWS instances."
}
