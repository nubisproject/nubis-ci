# nubis-ci

## Quick start
0. `git clone git@github.com:nubisproject/nubis-base.git`
0. `git clone git@github.com:nubisproject/nubis-builder.git`
0. Refer to README.md in nubis-builder on how to build this project.

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

