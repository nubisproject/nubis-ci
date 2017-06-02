include nubis_discovery

nubis::discovery::service { 'jenkins':
  tags     => [ 'jenkins' ],
  port     => '8080',
  check    => '/usr/bin/curl -fis http://localhost:8080/jenkins/cc.xml',
  interval => '30s',
}

package { 'daemon':
  ensure => 'present'
}->
class { 'jenkins':
  version            => '2.46.3',
  configure_firewall => false,
  service_enable     => false,
  service_ensure     => 'stopped',
  config_hash        => {
    'JENKINS_ARGS' => {
      'value' => '--webroot=/var/cache/$NAME/war --httpPort=$HTTP_PORT --prefix=$PREFIX'
    },
    'JAVA_ARGS' => {
      'value' => '-Djava.awt.headless=true -Dhudson.diyChunking=false -Dhttp.proxyHost=proxy.service.consul -Dhttp.proxyPort=3128 -Dhttps.proxyHost=proxy.service.consul -Dhttps.proxyPort=3128'
    },
  },
}

# Will eventually need to pull this from the registry
# jenkins::job { "nubis-ci":
#  enabled => 0,
#  config => template("/tmp/nubis-ci.xml.erb"),
# }

#XXX: Needs to be project-aware
#consul::service { 'jenkins':
#  tags           => ['nubis-ci'],
#  port           => 8080,
#  check_script   => '/usr/bin/wget -q -O- http://localhost:8080/cc.xml',
#  check_interval => '10s',
#}

## ADDITIONAL PLUGINS ##

jenkins::plugin { 'ace-editor':
    version => '1.1',
}

jenkins::plugin { 'jquery-detached':
    version => '1.2.1',
}

jenkins::plugin { 'cloudbees-folder':
    version => '6.0.4',
}

jenkins::plugin { 'matrix-auth':
    version => '1.6',
}

jenkins::plugin { 'reverse-proxy-auth-plugin':
    version => '1.5',
}

jenkins::plugin { 'ldap':
    version => '1.15',
}

jenkins::plugin { 'ansicolor':
    version => '0.5.0',
}

jenkins::plugin { 'naginator':
    version => '1.17.2',
}

jenkins::plugin { 'embeddable-build-status':
    version => '1.9',
}

jenkins::plugin { 'bouncycastle-api':
    version => '2.16.1',
}

jenkins::plugin { 'slack':
    version => '2.2',
}

jenkins::plugin { 'prometheus':
    version => '1.0.6',
}

jenkins::plugin { 'workflow-cps':
    version => '2.33',
}

jenkins::plugin { 'workflow-job':
    version => '2.11',
}

jenkins::plugin { 'workflow-api':
    version => '2.16',
}

jenkins::plugin { 'workflow-support':
    version => '2.14',
}

jenkins::plugin { 'workflow-multibranch':
    version => '2.15',
}

jenkins::plugin { 'branch-api':
    version => '2.0.9',
}

jenkins::plugin { 'metrics':
    version => '3.1.2.10',
}

jenkins::plugin { 'icon-shim':
    version => '2.0.3',
}

jenkins::plugin { 'git':
    version => '3.3.0',
}

jenkins::plugin { 'github':
    version => '1.27.0',
}

jenkins::plugin { 'github-api':
    version => '1.85.1',
}

jenkins::plugin { 'github-branch-source':
    version => '2.0.6',
}

jenkins::plugin { 'maven-plugin':
    version => '2.15.1',
}
jenkins::plugin { 'javadoc':
    version => '1.4',
}
jenkins::plugin { 'github-oauth':
    version => '0.27',
}
jenkins::plugin { 'workflow-scm-step':
    version => '2.4',
}
jenkins::plugin { 'workflow-step-api':
    version => '2.10',
}
jenkins::plugin { 'multiple-scms':
    version => '0.6',
}

jenkins::plugin { 'script-security':
    version => '1.27',
}

jenkins::plugin { 'parameterized-trigger':
    version => '2.33',
}

jenkins::plugin { 'jackson2-api':
    version => '2.7.3',
}

jenkins::plugin { 'token-macro':
    version => '2.1',
}

jenkins::plugin { 's3':
    version => '0.10.12',
}

jenkins::plugin { 'plain-credentials':
    version => '1.4',
}

jenkins::plugin { 'aws-java-sdk':
    version => '1.11.119',
}

jenkins::plugin { 'copyartifact':
    version => '1.38.1',
}

jenkins::plugin { 'matrix-project':
    version => '1.11',
}

jenkins::plugin { 'conditional-buildstep':
    version => '1.3.5',
}
jenkins::plugin { 'run-condition':
    version => '1.0',
}
jenkins::plugin { 'ssh-credentials':
    version => '1.13',
}

jenkins::plugin { 'mailer':
    version => '1.20',
}

jenkins::plugin { 'display-url-api':
    version => '2.0',
}

jenkins::plugin { 'junit':
    version => '1.20',
}

jenkins::plugin { 'structs':
    version => '1.7',
}

jenkins::plugin { 'git-client' :
    version => '2.4.6'
}

jenkins::plugin { 'scm-api' :
    version => '2.1.1',
}

jenkins::plugin { 'rebuild' :
    version => '1.25',
}

jenkins::plugin { 'promoted-builds':
    version => '2.28.1',
}

jenkins::plugin { 'pegdown-formatter':
    version => '1.3',
}

jenkins::plugin { 'thinBackup':
    version => '1.9',
}

# This is for librarian-puppet, below, and somewhat ugly
package { 'ruby-dev':
  ensure => '1:1.9.3.4',
}

package { 'librarian-puppet':
  ensure   => '2.2.3',
  provider => 'gem',
  require  => [
    Package['ruby-dev'],
  ],
}

# These are Ubuntu specific versions, needs fixing, but not with/without latest ?
package { 'unzip':
    ensure => '6.0-9ubuntu1.5',
}

package { 'git':
    ensure => '1:1.9.1-1ubuntu0.5',
}

package { 'make':
    ensure => '3.81-8.2ubuntu3',
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

python::pip { 's3cmd':
  ensure  => '1.6.1',
  require => Class['python'],
}

file { '/var/lib/jenkins/.s3cfg':
  require => [
    Class['jenkins'],
    Python::Pip['s3cmd'],
  ],
  owner   => 'jenkins',
  group   => 'jenkins',
  mode    => '0640',
  content => "[default]
proxy_host = proxy.service.consul
proxy_port = 3128
"
}

cron { 'jenkins-s3-backups':
  ensure      => 'present',
  command     => 'nubis-cron jenkins-s3-backups "test -f /mnt/jenkins/.initial-sync && s3cmd --quiet sync --exclude=.initial-sync --delete-removed /mnt/jenkins/ s3://$(nubis-metadata NUBIS_CI_BUCKET)/"',
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
