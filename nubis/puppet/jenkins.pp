include nubis_discovery

# XXX: This will need some post-bootup magic to include a project-specific tag, known only at bootup
# XXX: Environment too ?
nubis::discovery::service { 'jenkins':
  tags => [ 'jenkins' ],
  port => "8080",
  check => "/usr/bin/curl -is http://localhost:8080/cc.xml",
  interval => "30s",
}

package { 'daemon':
  ensure => 'present'
}->
class { 'jenkins':
  direct_download => "http://pkg.jenkins-ci.org/debian/binary/jenkins_1.658_all.deb",
  configure_firewall => false,
  service_enable => false,
  service_ensure => false,
  config_hash => {
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

jenkins::plugin { "icon-shim":
    version => "2.0.3",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "git":
    version => "2.4.4",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "github":
    version => "1.18.2",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "github-api":
    version => "1.75",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "github-oauth":
    version => "0.22.3",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "multiple-scms":
    version => "0.5",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "parameterized-trigger":
    version => "2.30",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "jackson2-api":
    version => "2.5.4",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "token-macro":
    version => "1.12.1",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "s3":
    version => "0.10.1",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "plain-credentials":
    version => "1.1",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "aws-java-sdk":
    version => "1.10.45",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "copyartifact":
    version => "1.38",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "git-client" :
    version => "1.19.6",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "scm-api" :
    version => "1.0",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "ansible" :
    version => "0.4",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "rebuild" :
    version => "1.25",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "promoted-builds":
    version => "2.25",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "pegdown-formatter":
    version => "1.3",
  update_url => 'https://updates.jenkins.io',
}

jenkins::plugin { "thinBackup":
    version => "1.7.4",
  update_url => 'https://updates.jenkins.io',
}

# This is for librarian-puppet, below, and somewhat ugly
package { "ruby-dev":
  ensure => "1:1.9.3.4",
}

package { "librarian-puppet":
  ensure => "2.2.1",
  provider => "gem",
  require => [
    Package["ruby-dev"],
  ],
}

# These are Ubuntu specific versions, needs fixing, but not with/without latest ?
package { "unzip":
    ensure => "6.0-9ubuntu1.5",
}

package { "git":
    ensure => "1:1.9.1-1ubuntu0.3",
}

package { "make":
    ensure => "3.81-8.2ubuntu3",
}

# Needed because current ansible/boto has bugs with STS tokens

class { 'python':
  version => 'system',
  pip => true,
  dev => true,
}

python::pip { 'boto':
  ensure => '2.38.0',
  require => Class['python'],
}

python::pip { 'ansible':
  ensure => '1.9.4',
  require => Class['python'],
}

wget::fetch { "download latest cloudformation ansible module (bugfix)":
  source => 'https://raw.githubusercontent.com/ansible/ansible-modules-core/e25605cd5bca003a5071aebbdaeb2887e8e5c659/cloud/amazon/cloudformation.py',
  destination => '/usr/local/lib/python2.7/dist-packages/ansible/modules/core/cloud/amazon/cloudformation.py',
  verbose => true,
  redownload => true, # The file already exists, we replace it
  require => [
    Python::Pip['ansible'],
  ]
}
