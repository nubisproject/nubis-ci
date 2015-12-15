include nubis_discovery

# XXX: This will need some post-bootup magic to include a project-specific tag, known only at bootup
# XXX: Environment too ?
nubis::discovery::service { 'jenkins':
  tags => [ 'jenkins' ],
  port => "8080",
  check => "/usr/bin/curl -is http://localhost:8080/cc.xml",
  interval => "30s",
}

class { 'jenkins':
  version => "1.641",
  configure_firewall => false,
  config_hash => {
    'JAVA_ARGS' => {
      'value' => '-Djava.awt.headless=true -Dhudson.diyChunking=false'
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

jenkins::plugin { "git":
    version => "2.4.0"
}

jenkins::plugin { "github":
    version => "1.14.0"
}

jenkins::plugin { "github-api":
    version => "1.69"
}

jenkins::plugin { "github-oauth":
    version => "0.22.2"
}

jenkins::plugin { "multiple-scms":
    version => "0.5"
}

jenkins::plugin { "parameterized-trigger":
    version => "2.29"
}

jenkins::plugin { "s3":
    version => "0.8"
}

jenkins::plugin { "plain-credentials":
    version => "1.1"
}

jenkins::plugin { "aws-java-sdk":
    version => "1.10.26"
}

jenkins::plugin { "copyartifact":
    version => "1.36.1"
}

jenkins::plugin { "git-client" :
    version => "1.19.0"
}

jenkins::plugin { "scm-api" :
    version => "0.2"
}

jenkins::plugin { "ansible" :
    version => "0.3.1"
}

jenkins::plugin { "rebuild" :
    version => "1.25"
}

jenkins::plugin { "promoted-builds":
    version => "2.23"
}

jenkins::plugin { "pegdown-formatter":
    version => "1.3"
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
    ensure => "6.0-9ubuntu1",
}

package { "git":
    ensure => "1:1.9.1-1",
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
  ensure => 'latest',
  require => Class['python'],
}

python::pip { 'ansible':
  ensure => 'latest',
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
