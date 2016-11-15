include nubis_discovery

nubis::discovery::service { 'jenkins':
  tags     => [ 'jenkins' ],
  port     => '8080',
  check    => '/usr/bin/curl -fis http://localhost:8080/cc.xml',
  interval => '30s',
}

package { 'daemon':
  ensure => 'present'
}->
class { 'jenkins':
  version            => '2.19.2',
  configure_firewall => false,
  service_enable     => false,
  service_ensure     => 'stopped',
  config_hash        => {
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

jenkins::plugin { 'embeddable-build-status':
    version => '1.9',
}

jenkins::plugin { 'bouncycastle-api':
    version => '2.16.0',
}

jenkins::plugin { 'slack':
    version => '2.0.1',
}

jenkins::plugin { 'prometheus':
    version => '1.0.6',
}

jenkins::plugin { 'workflow-job':
    version => '2.9',
}

jenkins::plugin { 'workflow-api':
    version => '2.6',
}
jenkins::plugin { 'workflow-support':
    version => '2.11',
}
jenkins::plugin { 'metrics':
    version => '3.1.2.9',
}

jenkins::plugin { 'icon-shim':
    version => '2.0.3',
}

jenkins::plugin { 'git':
    version => '3.0.0',
}

jenkins::plugin { 'github':
    version => '1.23.0',
}

jenkins::plugin { 'github-api':
    version => '1.79',
}

jenkins::plugin { 'maven-plugin':
    version => '2.14',
}
jenkins::plugin { 'javadoc':
    version => '1.4',
}
jenkins::plugin { 'github-oauth':
    version => '0.24',
}
jenkins::plugin { 'workflow-scm-step':
    version => '2.3',
}
jenkins::plugin { 'workflow-step-api':
    version => '2.5',
}
jenkins::plugin { 'multiple-scms':
    version => '0.6',
}

jenkins::plugin { 'script-security':
    version => '1.24',
}

jenkins::plugin { 'parameterized-trigger':
    version => '2.32',
}

jenkins::plugin { 'jackson2-api':
    version => '2.7.3',
}

jenkins::plugin { 'token-macro':
    version => '2.0',
}

jenkins::plugin { 's3':
    version => '0.10.10',
}

jenkins::plugin { 'plain-credentials':
    version => '1.3',
}

jenkins::plugin { 'aws-java-sdk':
    version => '1.11.37',
}

jenkins::plugin { 'copyartifact':
    version => '1.38.1',
}

jenkins::plugin { 'matrix-project':
    version => '1.7.1',
}

jenkins::plugin { 'conditional-buildstep':
    version => '1.3.5',
}
jenkins::plugin { 'run-condition':
    version => '1.0',
}
jenkins::plugin { 'ssh-credentials':
    version => '1.12',
}

jenkins::plugin { 'mailer':
    version => '1.18',
}

jenkins::plugin { 'display-url-api':
    version => '0.5',
}

jenkins::plugin { 'junit':
    version => '1.19',
}

jenkins::plugin { 'structs':
    version => '1.5',
}

jenkins::plugin { 'git-client' :
    version => '2.1.0',
}

jenkins::plugin { 'scm-api' :
    version => '1.3',
}

jenkins::plugin { 'ansible' :
    version => '0.5',
}

jenkins::plugin { 'rebuild' :
    version => '1.25',
}

jenkins::plugin { 'promoted-builds':
    version => '2.27',
}

jenkins::plugin { 'pegdown-formatter':
    version => '1.3',
}

jenkins::plugin { 'thinBackup':
    version => '1.7.4',
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
    ensure => '1:1.9.1-1ubuntu0.3',
}

package { 'make':
    ensure => '3.81-8.2ubuntu3',
}

# Needed because current ansible/boto has bugs with STS tokens

class { 'python':
  version => 'system',
  pip     => true,
  dev     => true,
}

python::pip { 'boto':
  ensure  => '2.38.0',
  require => Class['python'],
}

python::pip { 'ansible':
  ensure  => '1.9.4',
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

wget::fetch { 'download latest cloudformation ansible module (bugfix)':
  source      => 'https://raw.githubusercontent.com/ansible/ansible-modules-core/e25605cd5bca003a5071aebbdaeb2887e8e5c659/cloud/amazon/cloudformation.py',
  destination => '/usr/local/lib/python2.7/dist-packages/ansible/modules/core/cloud/amazon/cloudformation.py',
  verbose     => true,
  redownload  => true, # The file already exists, we replace it
  require     => [
    Python::Pip['ansible'],
  ]
}

cron { 'jenkins-s3-backups':
  ensure      => 'present',
  command     => 'test -f /mnt/jenkins/.initial-sync && s3cmd --quiet sync --exclude=.initial-sync --delete /mnt/jenkins/ s3://$(nubis-metadata NUBIS_CI_BUCKET)/',
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
