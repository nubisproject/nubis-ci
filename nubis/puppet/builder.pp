$terraform_version = '0.10.7'
$packer_version = '1.1.3'
$nubis_builder_version = 'v1.5.6'

package { 'awscli':
  ensure => latest,
}

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

vcsrepo { '/opt/nubis-builder':
  ensure   => present,
  provider => git,
  source   => 'https://github.com/nubisproject/nubis-builder.git',
  revision => $nubis_builder_version,
}

# XXX: need to move to puppet-packer
staging::file { 'packer.zip':
  source => "https://releases.hashicorp.com/packer/${packer_version}/packer_${packer_version}_linux_amd64.zip"
}
  -> staging::extract { 'packer.zip':
  target  => '/usr/local/bin',
  creates => '/usr/local/bin/packer',
}

# XXX: need to move to puppet-terraform	
staging::file { 'terraform.zip':
  source => "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip"
}
  -> staging::extract { 'terraform.zip':
  target  => '/usr/local/bin',
  creates => '/usr/local/bin/terraform',
}


