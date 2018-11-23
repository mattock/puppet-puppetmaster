notify { 'Running librarian-puppet': }

exec { 'Run librarian-puppet':
  cwd       => "${::basedir}",
  logoutput => true,
  command   => 'librarian-puppet install --verbose',
  timeout   => 600,
  logoutput => true,
  path      => ['/bin','/usr/bin','/opt/puppetlabs/bin','/opt/puppetlabs/puppet/bin'],
}

