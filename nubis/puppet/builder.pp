#XXX: Needs released version

$terraform_version = '0.8.8'
$packer_version = '1.0.0'
$nubis_builder_version = 'v1.5.0'

package { 'awscli':
  ensure => latest,
}

package { 'rsync':
  ensure => present
}

# XXX: We require jq 1.5, not in repos yet
exec { 'wget-jq':
  creates => '/usr/local/bin/jq',
  command => '/usr/bin/curl -Lfqs -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64'
} ->
file { '/usr/local/bin/jq':
  owner => 0,
  group => 0,
  mode  => '0755',
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
} ->
staging::extract { 'packer.zip':
  target  => '/usr/local/bin',
  creates => '/usr/local/bin/packer',
}

# XXX: need to move to puppet-terraform	
staging::file { 'terraform.zip':
  source => "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip"
} ->
staging::extract { 'terraform.zip':
  target  => '/usr/local/bin',
  creates => '/usr/local/bin/terraform',
}


