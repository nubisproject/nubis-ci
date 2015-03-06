#XXX: Needs released version

vcsrepo { "/opt/nubis-builder":
  ensure   => present,
  provider => git,
  source   => 'https://github.com/Nubisproject/nubis-builder.git',
  revision => '1f002ce0a1fefe58f158d31dc6b0cc2c6bdc8ca1',
}

# XXX: need to move to puppet-packer
staging::file { 'packer.zip':
  source => "https://dl.bintray.com/mitchellh/packer/packer_0.7.5_linux_amd64.zip"
} ->
staging::extract { 'packer.zip':
  target  => "/usr/local/bin",
  creates => "/usr/local/bin/packer",
}
