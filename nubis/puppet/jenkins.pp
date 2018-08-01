include nubis_discovery

nubis::discovery::service { 'jenkins':
  tags     => [ 'jenkins' ],
  port     => '8080',
  check    => '/usr/bin/curl -fis http://localhost:8080/jenkins/cc.xml',
  interval => '30s',
}

class { 'jenkins':
  version            => '2.121.2',
  #direct_download    => 'https://pkg.jenkins.io/debian-stable/binary/jenkins_2.46.3_all.deb',
  configure_firewall => false,
  service_enable     => false,
  service_ensure     => 'stopped',
  install_java       => true,
  config_hash        => {
    'JENKINS_ARGS' => {
      'value' => '--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT --prefix=$PREFIX --requestHeaderSize=32768'
    },
    'JAVA_ARGS'    => {
      'value' => '-Djava.awt.headless=true -Dhudson.diyChunking=false -Dhttp.proxyHost=proxy.service.consul -Dhttp.proxyPort=3128 -Dhttps.proxyHost=proxy.service.consul -Dhttps.proxyPort=3128'
    },
  },
}

Apt::Source['jenkins'] -> Class['apt::update'] -> Package['jenkins']

#XXX: Needs to be project-aware
#consul::service { 'jenkins':
#  tags           => ['nubis-ci'],
#  port           => 8080,
#  check_script   => '/usr/bin/wget -q -O- http://localhost:8080/cc.xml',
#  check_interval => '10s',
#}

# This is for librarian-puppet, below, and somewhat ugly
package { 'ruby-dev':
  ensure => '1:2.3.*',
}

package { 'librarian-puppet':
  ensure   => '2.2.3',
  provider => 'gem',
  require  => [
    Package['ruby-dev'],
    Package['puppet_forge'],
  ],
}

package { 'puppet_forge':
  ensure   => '2.2.6',
  provider => 'gem',
  require  => [
    Package['ruby-dev'],
  ],
}

# These are Ubuntu specific versions, needs fixing, but not with/without latest ?
package { 'unzip':
    ensure => '6.0-*',
}

package { 'make':
    ensure => '4.1-*',
}

# Needed for encrypted repos
package { 'git-crypt':
  ensure  => '0.5.0-*',
}

# In case we need entropy for key generation and all
package { 'rng-tools':
  ensure => '5-0*',
}

# Needed because current boto has bugs with STS tokens

class { 'python':
  version => 'system',
  pip     => true,
  dev     => true,
}

python::pip { 'boto':
  ensure  => '2.38.0',
  require => Class['python'],
}

python::pip { 'MarkupSafe':
  ensure  => '0.23',
  require => Class['python'],
}

python::pip { 'awscli':
  ensure  => '1.15.4',
  require => Class['python'],
}

file { '/usr/local/bin/nubis-ci-backup':
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0755',
  source => 'puppet:///nubis/files/nubis-ci-backup',
}

cron { 'jenkins-s3-backups':
  ensure      => 'present',
  command     => 'nubis-cron jenkins-s3-backups /usr/local/bin/nubis-ci-backup backup',
  hour        => '*',
  minute      => '*/15',
  user        => 'jenkins',
  environment => [
    'PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/opt/aws/bin',
  ],
  require     => [
    Class['jenkins'],
  ],
}

file { '/var/lib/jenkins/jobs/00-seed':
  ensure  => directory,
  owner   => 'jenkins',
  group   => 'jenkins',
  mode    => '0755',
  require => [
    File['/var/lib/jenkins/jobs'],
    Class['jenkins'],
  ],
}

file { '/etc/nubis.d/jenkins-seed-config.xml':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0644',
  source  => 'puppet:///nubis/files/seed.xml',

  require => [
    File['/var/lib/jenkins/jobs/00-seed'],
    Class['jenkins'],
  ],
}

# Jenkins is already defining the user for this, so cheat
exec { 'jenkins-docker-group':
  command => '/usr/sbin/usermod -G docker jenkins',
  require => [
    Class['jenkins'],
    Class['docker'],
  ],
}

file { '/var/lib/jenkins/.docker':
  ensure  => directory,
  owner   => jenkins,
  group   => jenkins,
  mode    => '0755',
  require => [
    Class['jenkins'],
    Class['docker'],
  ],
}

file { '/var/lib/jenkins/.docker/config.json':
  ensure  => file,
  owner   => jenkins,
  group   => jenkins,
  mode    => '0755',
  source  => 'puppet:///nubis/files/docker_config.json',
  require => [
    File['/var/lib/jenkins/.docker'],
    Class['jenkins'],
    Class['docker'],
  ],
}
