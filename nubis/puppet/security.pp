file { '/var/lib/jenkins/init.groovy.d':
  ensure => directory,
  owner  => root,
  group  => root,
  mode   => '0755',
}

file { '/var/lib/jenkins/init.groovy.d/cli-shutdown.groovy':
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0644',
  source => 'puppet:///nubis/files/cli-shutdown.groovy',
  
  require => [
    File['/var/lib/jenkins/init.groovy.d'],
    Class['jenkins'],
  ],
}
