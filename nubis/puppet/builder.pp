#XXX: Needs released version

# Amazon Linux upgraded python3 and broke boto, so install awscli and dependencies the hard way
package { "python3-pip":
  ensure => present
}->
exec { "upgrade awscli":
  command => "/usr/bin/pip3 install awscli",
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
  revision => "v1.0.2"
}

# XXX: need to move to puppet-packer
staging::file { 'packer.zip':
  source => "https://dl.bintray.com/mitchellh/packer/packer_0.8.2_linux_amd64.zip"
} ->
staging::extract { 'packer.zip':
  target  => "/usr/local/bin",
  creates => "/usr/local/bin/packer",
}

# XXX: need to move to puppet-terraform	
staging::file { 'terraform.zip':
  source => "https://dl.bintray.com/mitchellh/terraform/terraform_0.6.0_linux_amd64.zip"
} ->
staging::extract { 'terraform.zip':
  target  => "/usr/local/bin",
  creates => "/usr/local/bin/terraform",
}


