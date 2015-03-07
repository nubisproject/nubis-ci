class { 'jenkins':
  version => "1.601"
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
    version => "2.3.4"
}

jenkins::plugin { "git-client" :
    version => "1.15.0"
}

jenkins::plugin { "scm-api" :
    version => "0.2"
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
