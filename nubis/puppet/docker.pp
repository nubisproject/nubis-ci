include ::apt

exec { 'inhibit service startup on package installation':
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
  command => 'echo exit 101 > /usr/sbin/policy-rc.d; chmod +x /usr/sbin/policy-rc.d',
}
  -> class { 'docker':
  proxy => 'http://proxy.service.consul:3128/',
  bip   => '172.17.42.1/16',
}
  -> exec { 'un-inhibit service startup on package installation':
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
  command => 'rm -f /usr/sbin/policy-rc.d',
}

# Fix uncler dependency ordering on apt update from Docker
Apt::Source[docker] -> Class['apt::update'] -> Package['docker']

file { '/etc/dnsmasq.d/docker.conf':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  content => 'interface=docker0',
}

file { '/etc/resolvconf/resolv.conf.d/tail':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  content => "nameserver 172.17.42.1\n",
}

systemd::unit_file { 'docker-cleanup.service':
  source => 'puppet:///nubis/files/docker-cleanup.systemd',
}
->service { 'docker-cleanup':
  ensure => 'stopped',
  enable => true,
}
