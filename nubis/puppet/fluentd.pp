class { 'fluentd':
  service_ensure => stopped
}

fluentd::configfile { 'jenkins': }

fluentd::source { 'jenkins_log':
  configfile => 'jenkins',
  type       => 'tail',
  format     => 'none',
  tag        => 'forward.jenkins.general',
  config     => {
    'path' => '/var/log/jenkins/jenkins.log',
  },
}
