file { '/var/lib/jenkins/init.groovy.d':
  ensure => directory,
  owner  => root,
  group  => root,
  mode   => '0755',
}
