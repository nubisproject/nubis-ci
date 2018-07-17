$nubis_json2hcl_version = 'v0.0.2'
$nubis_jq_version = 'v0.1.0'
$nubis_builder_version = 'v1.11.0'
$nubis_deploy_version = 'v1.0.1'

include ::apt

exec { 'inhibit service startup on package installation':
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
  command => 'echo exit 101 > /usr/sbin/policy-rc.d; chmod +x /usr/sbin/policy-rc.d',
}
  -> class { 'docker':
# Proxy needs to be set up after downloading images
#  proxy => 'http://proxy.service.consul:3128/',
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

docker::image { "nubisproject/nubis-json2hcl:$nubis_json2hcl_version" : }
-> docker::image { "nubisproject/nubis-jq:$nubis_jq_version" : }
-> docker::image { "nubisproject/nubis-builder:$nubis_builder_version": }
-> docker::image { "nubisproject/nubis-deploy:$nubis_deploy_version": }
  -> exec { 'alias images for local':
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
  command => "docker tag nubisproject/nubis-json2hcl:$nubis_json2hcl_version nubis-json2hcl; docker tag nubisproject/nubis-jq:$nubis_jq_version nubis-jq; docker tag nubisproject/nubis-builder:$nubis_builder_version nubis-builder; docker tag nubisproject/nubis-deploy:$nubis_deploy_version nubis-deploy",
}
  -> exec { 'make docker proxy aware':
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
  command => 'echo \\\nhttp_proxy=\'http://proxy.service.consul:3128/\'\\\nhttps_proxy=\'http://proxy.service.consul:3128/\'\\\n >> /etc/default/docker',
}
