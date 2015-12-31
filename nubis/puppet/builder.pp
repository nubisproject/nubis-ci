#XXX: Needs released version

package { "awscli":
  ensure => latest,
}

package { "rsync":
  ensure => present
}

# XXX: We require jq 1.4, not in repos yet
exec { "wget-jq":
  creates => "/usr/local/bin/jq",
  command => "/usr/bin/curl -s -o /usr/local/bin/jq http://stedolan.github.io/jq/download/linux64/jq",
} ->
file { "/usr/local/bin/jq":
  owner => 0,
  group => 0,
  mode  => 755,
}

vcsrepo { "/opt/nubis-builder":
  ensure   => present,
  provider => git,
  source   => 'https://github.com/Nubisproject/nubis-builder.git',
  revision => "v1.0.1-final"
}

# XXX: need to move to puppet-packer
staging::file { 'packer.zip':
  source => "https://dl.bintray.com/mitchellh/packer/packer_0.8.6_linux_amd64.zip"
} ->
staging::extract { 'packer.zip':
  target  => "/usr/local/bin",
  creates => "/usr/local/bin/packer",
}

# XXX: need to move to puppet-terraform	
staging::file { 'terraform.zip':
  source => "https://dl.bintray.com/mitchellh/terraform/terraform_0.6.8_linux_amd64.zip"
} ->
staging::extract { 'terraform.zip':
  target  => "/usr/local/bin",
  creates => "/usr/local/bin/terraform",
}


