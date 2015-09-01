# Change Log

## [v1.0.0](https://github.com/nubisproject/nubis-ci/tree/v1.0.0) (2015-08-31)

[Full Changelog](https://github.com/nubisproject/nubis-ci/compare/v0.9.0...v1.0.0)

**Implemented enhancements:**

- CI needs to be able to deploy in the new multiple-VPCs in one account [\#84](https://github.com/Nubisproject/nubis-ci/issues/84)

**Closed issues:**

- Rename KeyName to SSHKeyName [\#63](https://github.com/Nubisproject/nubis-ci/issues/63)

**Merged pull requests:**

- Convert to the one-app-per-account layout [\#88](https://github.com/Nubisproject/nubis-ci/pull/88) ([gozer](https://github.com/gozer))

- A big PR to allow CI to publish to the multiple-vpcs-per-account layout [\#86](https://github.com/Nubisproject/nubis-ci/pull/86) ([gozer](https://github.com/gozer))

- pin at nubis-builder v0.9.0 [\#70](https://github.com/Nubisproject/nubis-ci/pull/70) ([gozer](https://github.com/gozer))

## [v0.9.0](https://github.com/nubisproject/nubis-ci/tree/v0.9.0) (2015-07-22)

**Closed issues:**

- Reconfigure ci to use nubis-consul script [\#51](https://github.com/Nubisproject/nubis-ci/issues/51)

- Generate /opt/nubis-builder/secrets/variables.json [\#39](https://github.com/Nubisproject/nubis-ci/issues/39)

- Simple lockdown password [\#12](https://github.com/Nubisproject/nubis-ci/issues/12)

- Authentication & Authorization [\#11](https://github.com/Nubisproject/nubis-ci/issues/11)

- move all jenkins setup into puppet [\#9](https://github.com/Nubisproject/nubis-ci/issues/9)

**Merged pull requests:**

- Updating changelog for v0.9.0 release [\#69](https://github.com/Nubisproject/nubis-ci/pull/69) ([gozer](https://github.com/gozer))

- Upgrade terraform to 0.6.0, fixes \#66 [\#68](https://github.com/Nubisproject/nubis-ci/pull/68) ([gozer](https://github.com/gozer))

- Upgrade packer to 0.8.2, fixes \#65 [\#67](https://github.com/Nubisproject/nubis-ci/pull/67) ([gozer](https://github.com/gozer))

- Rename KeyName to SSHKeyName, for nubisproject/nubis-docs\#35 [\#64](https://github.com/Nubisproject/nubis-ci/pull/64) ([gozer](https://github.com/gozer))

- use curl instead of ec2metadata [\#57](https://github.com/Nubisproject/nubis-ci/pull/57) ([gozer](https://github.com/gozer))

- publish URLs to Consul [\#56](https://github.com/Nubisproject/nubis-ci/pull/56) ([gozer](https://github.com/gozer))

- More verbose [\#55](https://github.com/Nubisproject/nubis-ci/pull/55) ([gozer](https://github.com/gozer))

- A client error \(ValidationError\) occurred when calling the AssumeRole operation: 1 validation error detected: Value '2/fluent-collector-deployment' at 'roleSessionName' failed to satisfy constraint: Member must satisfy regular expression pattern: \[\w+=,.@-\]\* [\#54](https://github.com/Nubisproject/nubis-ci/pull/54) ([gozer](https://github.com/gozer))

- Switch to using nubis-consul \(closes issue \#51\) [\#53](https://github.com/Nubisproject/nubis-ci/pull/53) ([gozer](https://github.com/gozer))

- fix tyop [\#52](https://github.com/Nubisproject/nubis-ci/pull/52) ([gozer](https://github.com/gozer))

- STS: role-session-name must be 32 characters or less [\#50](https://github.com/Nubisproject/nubis-ci/pull/50) ([gozer](https://github.com/gozer))

- upgrade plugins [\#49](https://github.com/Nubisproject/nubis-ci/pull/49) ([gozer](https://github.com/gozer))

- Add missing files. [\#48](https://github.com/Nubisproject/nubis-ci/pull/48) ([gozer](https://github.com/gozer))

- Working Deploys, v0.01 [\#47](https://github.com/Nubisproject/nubis-ci/pull/47) ([gozer](https://github.com/gozer))

- fix dependencies in puppet foo [\#46](https://github.com/Nubisproject/nubis-ci/pull/46) ([gozer](https://github.com/gozer))

- Install a more up-to-date version of ansible, to work around STS bugs [\#45](https://github.com/Nubisproject/nubis-ci/pull/45) ([gozer](https://github.com/gozer))

- bump up git operation timeouts for large git repositories [\#44](https://github.com/Nubisproject/nubis-ci/pull/44) ([gozer](https://github.com/gozer))

- Include a handy STS wrapper [\#43](https://github.com/Nubisproject/nubis-ci/pull/43) ([gozer](https://github.com/gozer))

- Many improvements for continuous deployment [\#42](https://github.com/Nubisproject/nubis-ci/pull/42) ([gozer](https://github.com/gozer))

- include jenkins ansible module [\#41](https://github.com/Nubisproject/nubis-ci/pull/41) ([gozer](https://github.com/gozer))

- Cosmetic fixes and tyops [\#40](https://github.com/Nubisproject/nubis-ci/pull/40) ([gozer](https://github.com/gozer))

- more informative curl output [\#38](https://github.com/Nubisproject/nubis-ci/pull/38) ([gozer](https://github.com/gozer))

- more informative curl output [\#37](https://github.com/Nubisproject/nubis-ci/pull/37) ([gozer](https://github.com/gozer))

- turns out Jenkins doesnt need to know the name of the IAM Profile of the instance [\#36](https://github.com/Nubisproject/nubis-ci/pull/36) ([gozer](https://github.com/gozer))

- Bug: Forgot to include the iam\_profile to the launch configuration [\#35](https://github.com/Nubisproject/nubis-ci/pull/35) ([gozer](https://github.com/gozer))

- Large, ugly rebased commit that switches Jenkis to using an AutoScaling Group. [\#34](https://github.com/Nubisproject/nubis-ci/pull/34) ([gozer](https://github.com/gozer))

- Convert over to VPC networking [\#33](https://github.com/Nubisproject/nubis-ci/pull/33) ([gozer](https://github.com/gozer))

- Enable publication [\#32](https://github.com/Nubisproject/nubis-ci/pull/32) ([gozer](https://github.com/gozer))

- Sartup fixes [\#30](https://github.com/Nubisproject/nubis-ci/pull/30) ([gozer](https://github.com/gozer))

- Fix tyop [\#29](https://github.com/Nubisproject/nubis-ci/pull/29) ([gozer](https://github.com/gozer))

- make the CI AMI an input variable [\#28](https://github.com/Nubisproject/nubis-ci/pull/28) ([gozer](https://github.com/gozer))

- Add S3 Artifact archival option and plugin [\#27](https://github.com/Nubisproject/nubis-ci/pull/27) ([gozer](https://github.com/gozer))

- include the instance in the outputs too [\#26](https://github.com/Nubisproject/nubis-ci/pull/26) ([gozer](https://github.com/gozer))

- add a few more jenkins plugins [\#25](https://github.com/Nubisproject/nubis-ci/pull/25) ([gozer](https://github.com/gozer))

- just use latest Jenkins, its a fast moving target [\#24](https://github.com/Nubisproject/nubis-ci/pull/24) ([gozer](https://github.com/gozer))

- Cleanups for getting deployment builds ready [\#23](https://github.com/Nubisproject/nubis-ci/pull/23) ([gozer](https://github.com/gozer))

- More fixups for nubis-builder [\#22](https://github.com/Nubisproject/nubis-ci/pull/22) ([gozer](https://github.com/gozer))

- Convert CI to nubis-builder [\#21](https://github.com/Nubisproject/nubis-ci/pull/21) ([gozer](https://github.com/gozer))

- merge from bhourigan's pull request [\#19](https://github.com/Nubisproject/nubis-ci/pull/19) ([gozer](https://github.com/gozer))

- Converted module over to nubis-builder [\#18](https://github.com/Nubisproject/nubis-ci/pull/18) ([bhourigan](https://github.com/bhourigan))

- Cleanup output and don't run packer in deployment target [\#17](https://github.com/Nubisproject/nubis-ci/pull/17) ([gozer](https://github.com/gozer))

- disable packer color output [\#16](https://github.com/Nubisproject/nubis-ci/pull/16) ([gozer](https://github.com/gozer))

- various fixups [\#15](https://github.com/Nubisproject/nubis-ci/pull/15) ([gozer](https://github.com/gozer))

- Convert to a TF module [\#14](https://github.com/Nubisproject/nubis-ci/pull/14) ([gozer](https://github.com/gozer))

- update to newer base image 0.165 and jenkins 1.599 [\#13](https://github.com/Nubisproject/nubis-ci/pull/13) ([gozer](https://github.com/gozer))

- fixups for top-level nubis/ structure [\#10](https://github.com/Nubisproject/nubis-ci/pull/10) ([gozer](https://github.com/gozer))

- Don't invoke packer by default at the moment [\#8](https://github.com/Nubisproject/nubis-ci/pull/8) ([gozer](https://github.com/gozer))

- split repos and use base AMIs [\#7](https://github.com/Nubisproject/nubis-ci/pull/7) ([gozer](https://github.com/gozer))

- further nubis/ move fixups [\#6](https://github.com/Nubisproject/nubis-ci/pull/6) ([gozer](https://github.com/gozer))

- make knows how to cd [\#5](https://github.com/Nubisproject/nubis-ci/pull/5) ([gozer](https://github.com/gozer))

- cleanup one extra rename [\#4](https://github.com/Nubisproject/nubis-ci/pull/4) ([gozer](https://github.com/gozer))

- move nubis related things to a nubis/ subfolder [\#3](https://github.com/Nubisproject/nubis-ci/pull/3) ([gozer](https://github.com/gozer))

- Puppet [\#2](https://github.com/Nubisproject/nubis-ci/pull/2) ([gozer](https://github.com/gozer))

- split repos and use base AMIs [\#1](https://github.com/Nubisproject/nubis-ci/pull/1) ([gozer](https://github.com/gozer))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*