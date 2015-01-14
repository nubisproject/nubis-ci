class { 'jenkins':
  version => "1.596"
}

# Will eventually need to pull this from the registry
# jenkins::job { "nubis-ci":
#  enabled => 0,
#  config => template("/tmp/nubis-ci.xml.erb"),
# }

jenkins::plugin { "packer" :
    version => "1.0"
}

jenkins::plugin { "git" :
    version => "2.3.4"
}

jenkins::plugin { "git-client" :
    version => "1.15.0"
}

jenkins::plugin { "scm-api" :
    version => "0.2"
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
