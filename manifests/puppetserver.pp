# Setup standalone Puppetserver without anything else extra
#
# == Parameters:
#
# $autosign:: Set up autosign entries. Set to true to enable naive autosigning.
#
# $autosign_entries:: List of autosign entries. Requires that autosign is pointing to the path of autosign.conf.
#
# $timezone:: The timezone the server wants to be located in. Example: 'Europe/Helsinki' or 'Etc/UTC'.
#
# $control_repo:: Enable control repository. You MUST also set up $provider, $repo_url, $key_path and $repo_host
#                 in Advanced parameters to use this functionality. Defaults to false.
#
# == Advanced parameters:
#
# $manage_packetfilter:: Manage IPv4 and IPv6 rules. Defaults to false.
#
# $puppetserver_allow_ipv4:: Allow connections to puppetserver from this IPv4 address or subnet.
#                            Example: '10.0.0.0/8'. Defaults to '127.0.0.1'.
#
# $puppetserver_allow_ipv6:: Allow connections to puppetserver from this IPv6 address or subnet. Defaults to '::1'.
#
# $server_reports:: Where to store reports. Defaults to 'store'.
#
# $server_external_nodes:: The path to the ENC executable. Defaults to empty string.
#
# $server_foreman:: Used internally in Foreman scenarios. Do not change the default (false) unless you know what you are doing.
#
# $show_diff:: Used internally in Foreman scenarios. Do not change the default (false) unless you know what you are doing.
#
# $provider:: Your git repository provider. Currently supported are: 'gitlab'.
# 
# $repo_url:: The url to your control repository. Example: 'git@gitlab.com:mycompany/control-repo.git'
#
# $key_path:: The private key to use for accessing $repo_url. defaults to '/etc/puppetlabs/r10k/ssh/r10k_key'
# 
# $repo_host:: The fully qualified name of the $provider host. Example gitlab.com
#
class puppetmaster::puppetserver
(
  String                   $timezone = 'Etc/UTC',
  Boolean                  $manage_packetfilter = false,
  String                   $puppetserver_allow_ipv4 = '127.0.0.1',
  String                   $puppetserver_allow_ipv6 = '::1',
  String                   $server_reports = 'store',
  Variant[Boolean, String] $autosign = '/etc/puppetlabs/puppet/autosign.conf',
  Boolean                  $show_diff = false,
  Boolean                  $server_foreman = false,
  String                   $server_external_nodes = '',
  String                   $key_path = '/etc/puppetlabs/r10k/ssh/r10k_key',
  Boolean                  $control_repo = false,
  Optional[Enum['gitlab']] $provider = undef,
  Optional[Array[String]]  $autosign_entries = undef,
  Optional[String]         $repo_url = undef,
  Optional[String]         $repo_host = undef,
)
{

  if $control_repo {
    unless $provider and $repo_url and $key_path and $repo_host {
      notify { 'Control repository functionality is enabled. You must also define $provider, $repo_url and $repo_host': }
      $use_control_repo = false
    }
    else {
      $use_control_repo = true
    }
  }

  $primary_names = unique([ $facts['fqdn'], $facts['hostname'], 'puppet', "puppet.${facts['domain']}" ])

  class { '::puppetmaster::common':
    primary_names => $primary_names,
    timezone      => $timezone,
    provider      => $provider,
    key_path      => $key_path,
    control_repo  => $use_control_repo,
    repo_url      => $repo_url,
    repo_host     => $repo_host,
  }

  file { '/var/files':
    ensure => 'directory',
    mode   => '0660',
    owner  => 'puppet',
    group  => 'puppet',
  }

  file { '/etc/puppetlabs/puppet/fileserver.conf':
    ensure => 'present'
  }

  ini_setting { 'files_path':
    ensure            => present,
    path              => '/etc/puppetlabs/puppet/fileserver.conf',
    section           => 'files',
    setting           => 'path',
    value             => '/var/files',
    key_val_separator => ' ',
    require           => File['/etc/puppetlabs/puppet/fileserver.conf'],
  }

  ini_setting { 'files_allow':
    ensure            => present,
    path              => '/etc/puppetlabs/puppet/fileserver.conf',
    section           => 'files',
    setting           => 'allow',
    value             => '*',
    key_val_separator => ' ',
    require           => File['/etc/puppetlabs/puppet/fileserver.conf'],
  }

  puppet_authorization::rule { 'files':
    match_request_path => '^/puppet/v3/file_(content|metadata)s?/files/',
    match_request_type => 'regex',
    allow              => '*',
    sort_order         => 400,
    path               => '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  }

  class { '::puppet':
    server                                 => true,
    show_diff                              => $show_diff,
    server_foreman                         => $server_foreman,
    autosign                               => $autosign,
    autosign_entries                       => $autosign_entries,
    server_reports                         => $server_reports,
    server_external_nodes                  => $server_external_nodes,
    server_environment_class_cache_enabled => true,
    require                                => [ File['/etc/puppetlabs/puppet/fileserver.conf'], Puppet_authorization::Rule['files'] ],
  }

  if $manage_packetfilter {
    include ::packetfilter::endpoint

    $firewall_defaults = {
      dport  => '8140',
      proto  => 'tcp',
      action => 'accept',
      tag    => 'default',
    }

    @firewall { '8140 accept incoming agent ipv4 traffic to puppetserver':
      provider => 'iptables',
      source   => $puppetserver_allow_ipv4,
      *        => $firewall_defaults,
    }

    @firewall { '8140 accept incoming agent ipv6 traffic to puppetserver':
      provider => 'ip6tables',
      source   => $puppetserver_allow_ipv6,
      *        => $firewall_defaults,
    }
  }
}
