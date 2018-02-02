file { '/var/lib/jenkins/init.groovy.d':
  ensure => directory,
  owner  => root,
  group  => root,
  mode   => '0755',
}

file { '/var/lib/jenkins/init.groovy.d/newrelic.groovy':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  source  => 'puppet:///nubis/files/newrelic.groovy',

  require => [
    File['/var/lib/jenkins/init.groovy.d'],
    Class['jenkins'],
  ],
}
