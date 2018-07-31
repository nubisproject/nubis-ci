$apt_repo_url = "http://apt.kubernetes.io/"

include ::apt

apt::source { 'kubectl':
  location => $apt_repo_url,
  release  => "kubernetes-${::lsbdistcodename}",
  repos    => 'main',
  key      => {
    id     => '54A647F9048D5688D7DA2ABE6A030B21BA07F4FB',
    source => 'https://packages.cloud.google.com/apt/doc/apt-key.gpg'
  },
  include   =>  {
    src => false,
 },
}

package { 'kubectl':
  ensure => present,
}

# dependency chain
Apt::Source['kubectl'] -> Class['apt::update'] -> Package['kubectl']
