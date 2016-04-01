variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "environment" {
  description = "Name of the environment this deployment is for"
  default = "sandbox"
}

variable "nubis_domain" {
  description = "Top-level Nubis domain for this environemnt"
  default = "nubis.allizom.org"
}

variable "region" {
  default = "us-east-1"
  description = "The region of AWS, for AMI lookups and where to launch"
}

variable "admins" {
  description = "GitHub userids that should be admins, comma separated"
  default = "gozer"
}

variable "organizations" {
  description = "GitHub organizations that should be build users, comma separated"
  default = "nubisproject"
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth client id"
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth client secret"
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

variable "https_cert_arn" {
  description = "ARN of the SSL cert to use for https traffic"
}

variable "version" {
  description = "Version of nubis-ci to deploy"
}

variable "technical_contact" { 
  default = "gozer@mozilla.com"
}

# Work around a limitation in TF, keep it an ordered list of
# regions indexed at 0, must match what is being built as an
# Artifact. WARNING: brittleness!
variable "atlas_region_map" {
  default = {
    "us-east-1" = 0
    "us-west-2" = 1
  }
}
