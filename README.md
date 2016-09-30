# nubis-ci [![Build Status](https://travis-ci.org/nubisproject/nubis-ci.svg?branch=master)](https://travis-ci.org/nubisproject/nubis-ci)

## Quick start
0. `git clone git@github.com:nubisproject/nubis-base.git`
0. `git clone git@github.com:nubisproject/nubis-builder.git`
0. Refer to README.md in nubis-builder on how to build this project.

## Github Authentication

You need to create a new OAuth application by going to : https://github.com/settings/applications/new

Set the homepage to https://ci.<application>.admin.us-east-1.<account>.nubis.allizom.org/
Set the callback URL to https://ci.<application>.admin.us-east-1.<account>.nubis.allizom.org/securityRealm/finishLogin

And use the provided Client ID and Client Secret as inputs, respectively: github_oauth_client_id and github_oauth_client_secret

## File structure

##### `nubis`
All files related to the nubis ci project

##### `nubis/bin`
Scripts related to configuring nubis-ci AMIs creation

##### `nubis/nubis-puppet`
This is the puppet tree that's populated with librarian-puppet, it's in .gitignore and gets reset on every build.

##### `nubis/builder`
JSON files that describe the project, configure settings, configure provisioners, etc.

##### `nubis/terraform`
Terraform deployment templates.
