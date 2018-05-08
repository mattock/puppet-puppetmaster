# Setup Puppetserver with PuppetDB
#
# == Parameters:
#
# $manage_packetfilter:: Manage IPv4 and IPv6 rules. Defaults to true.
#
# $puppetserver_allow_ipv4:: Allow connections to puppetserver from this IPv4 address or subnet. Example: '10.0.0.0/8'. Defaults to '127.0.0.1'.
#
# $puppetserver_allow_ipv6:: Allow connections to puppetserver from this IPv6 address or subnet. Defaults to '::1'.
#
# $server_reports:: Where to store reports. Defaults to 'store,puppetdb'.
#
# $autosign:: Set up autosign entries. Set to true to enable naive autosigning.
#
# $autosign_entries:: List of autosign entries. Requires that autosign is pointing to the path of autosign.conf.
#
# $puppetdb_database_password:: Password for the puppetdb database in postgresql
#
# $timezone:: The timezone the server wants to be located in. Example: 'Europe/Helsinki' or 'Etc/UTC'.
#
class puppetmaster::puppetdb
(
  Boolean                  $manage_packetfilter = true,
  String                   $puppetserver_allow_ipv4 = '127.0.0.1',
  String                   $puppetserver_allow_ipv6 = '::1',
  String                   $server_reports = 'store,puppetdb',
  Variant[Boolean, String] $autosign = '/etc/puppetlabs/puppet/autosign.conf',
  Optional[Array[String]]  $autosign_entries = undef,
  String                   $puppetdb_database_password,
  String                   $timezone
)
{
  class { '::puppetmaster::puppetserver':
    manage_packetfilter     => $manage_packetfilter,
    puppetserver_allow_ipv4 => $puppetserver_allow_ipv4,
    puppetserver_allow_ipv6 => $puppetserver_allow_ipv6,
    server_reports          => $server_reports,
    autosign                => $autosign,
    autosign_entries        => $autosign_entries,
    timezone                => $timezone, 
  }

  class { '::puppetdb':
    database_password => $puppetdb_database_password,
    ssl_deploy_certs  => true,
    database_validate => false,
  }

  class { '::puppetdb::master::config':
    puppetdb_server     => $facts['fqdn'],
    restart_puppet      => true,
  }
}
