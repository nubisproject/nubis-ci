# Consul needs to be configured for a bind IP when there are multiple on the node
file { '/etc/nubis.d/0-consul-bind-startup':
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0755',
  source => 'puppet:///nubis/files/consul_bind_ip',
}
