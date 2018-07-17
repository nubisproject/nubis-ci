$nubis_ctl_version = 'v0.3.5'
# NOTE: docker containers versions managed in docker.pp file

package { 'rsync':
  ensure => present
}

file { '/usr/local/bin/nubis-ci-build':
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0755',
  source => 'puppet:///nubis/files/nubis-ci-build',
}

file { '/usr/local/bin/nubis-ci-deploy':
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0755',
  source => 'puppet:///nubis/files/nubis-ci-deploy',
}

vcsrepo { '/opt/nubis-ctl':
  ensure   => present,
  provider => git,
  source   => 'https://github.com/nubisproject/nubis-ctl.git',
  revision => $nubis_ctl_version,
}
