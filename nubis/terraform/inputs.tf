variable "arena" {
  description = "Name of the arena this deployment is for"
  default = "core"
}

variable "nubis_domain" {
  description = "Top-level Nubis domain for this environemnt"
  default = "nubis.allizom.org"
}

variable "enabled" {
  default = "1"
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

variable "git_repo" {
  description = "URL to git repo to build"
  default = "https://github.com/mozilla/nubis-ci.git"
}

variable "git_branches" {
  description = "List of Git branch specs to follow"
  default = "refs/heads/master"
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

variable monitoring_security_group_id {
  description = "ID of that SG"
}

variable sso_security_group_id {
  description = "ID of that SG"
  default = ""
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

variable "email" {
  description = "e-mail to send build notifications to"
  default = "gozer@mozilla.com"
}

variable "version" {
  description = "Version of nubis-ci to deploy"
}

variable "technical_contact" { 
  default = "infra-aws@mozilla.com"
}

variable "credstash_key" {

}

variable "slack_domain" {
  default = "mozilla"
}

variable "slack_channel" {
  default = "#nubis-changes"
}

variable "slack_token" {
  default = ""
}

variable nubis_sudo_groups {
  default = "nubis_global_admins"
}

variable nubis_user_groups {
  default = ""
}

variable instance_type {
  default = "t2.micro"
}

variable consul_acl_token {}
