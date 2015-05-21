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
  version => "latest",
  configure_firewall => false,
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

jenkins::plugin { "git" :
    version => "2.3.5"
}

jenkins::plugin { "github":
    version => "1.11.3"
}

jenkins::plugin { "github-api":
    version => "1.67"
}

jenkins::plugin { "multiple-scms":
    version => "0.4"
}

jenkins::plugin { "parameterized-trigger":
    version => "2.26"
}

jenkins::plugin { "s3":
    version => "0.7"
}

jenkins::plugin { "copyartifact":
    version => "1.35.1"
}

jenkins::plugin { "git-client" :
    version => "1.17.1"
}

jenkins::plugin { "scm-api" :
    version => "0.2"
}

jenkins::plugin { "ansible" :
    version => "0.2"
}

jenkins::plugin { "rebuild" :
    version => "1.24"
}

jenkins::plugin { "promoted-builds":
    version => "2.21"
}

# This is for librarian-puppet, below, and somewhat ugly
package { "ruby-dev":
  ensure => "1:1.9.3.4",
}

package { "librarian-puppet":
  ensure => "2.0.1",
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
  source => 'https://raw.githubusercontent.com/ansible/ansible-modules-core/devel/cloud/amazon/cloudformation.py',
  destination => '/usr/local/lib/python2.7/dist-packages/ansible/modules/core/cloud/amazon/cloudformation.py',
  verbose => true,
  redownload => true, # The file already exists, we replace it
  require => [
    Python::Pip['ansible'],
  ]
}
