# == Class: aerospike
#
# Manage an aerospike installation, configuration and service.
# It can optionally install the amc console and manage the corresponding
# service.
#
# For the full documentation, please refer to:
# https://github.com/deric/puppet-aerospike/blob/master/README.md
#
class aerospike (
  Boolean              $asinstall                = true,
  String               $version                  = '5.7.0.11',
  Stdlib::Absolutepath $download_dir             = '/usr/local/src',
  Optional[String]     $download_url             = undef,
  Boolean              $remove_archive           = false,
  String               $edition                  = 'community',
  String               $target_os_tag            = $aerospike::params::target_os_tag,
  Optional[String]     $download_user            = undef,
  Optional[String]     $download_pass            = undef,
  Optional[String]     $asinstall_params         = undef,
  String               $system_user              = 'root',
  Optional[Integer]    $system_uid               = undef,
  String               $system_group             = 'root',
  Optional[Integer]    $system_gid               = undef,
  Boolean              $manage_service           = true,
  Boolean              $restart_on_config_change = true,
  Boolean              $enable_logging           = true,
  Hash                 $config_service           = {
    'paxos-single-replica-limit'    => 1,
    'pidfile'                       => '/var/run/aerospike/asd.pid',
    'service-threads'               => 4,
    'transaction-queues'            => 4,
    'transaction-threads-per-queue' => 4,
    'proto-fd-max'                  => 15000,
  },
  Hash $config_logging = $aerospike::params::config_logging,
  Hash $config_mod_lua = {},
  Hash $config_net_svc = {
    'address' => 'any',
    'port'    => 3000,
  },
  Hash $config_net_fab = {
    'address' => 'any',
    'port'    => 3001,
  },
  Hash $config_net_inf = {
    'address' => 'any',
    'port'    => 3003,
  },
  Hash $config_net_hb  = {
    'mode'     => 'multicast',
    'address'  => 'any',
    'port'     => 9918,
    'interval' => 150,
    'timeout'  => 10,
  },
  Hash $config_ns      = {
    'foo'                     => {
      'replication-factor'    => 2,
      'memory-size'           => '1G',
      'storage-engine device' => [
        'file /data/aerospike/data1.dat',
        'file /data/aerospike/data2.dat',
        'filesize 10G',
        'data-in-memory false',
      ],
    },
  },
  Hash                 $config_cluster         = {},
  Hash                 $config_sec             = {},
  Hash                 $config_xdr             = {},
  Hash                 $config_xdr_credentials = {},
  String               $service_status         = 'running',
  Boolean              $service_enable         = true,
  Optional[String]     $service_provider       = undef,
  Boolean              $amc_install            = false,
  String               $amc_version            = '4.0.19',
  Stdlib::Absolutepath $amc_download_dir       = '/usr/local/src',
  Optional[String]     $amc_download_url       = undef,
  Boolean              $amc_manage_service     = false,
  String               $amc_service_status     = 'running',
  Boolean              $amc_service_enable     = true,
  Optional[String]     $tools_version          = undef,
  Optional[String]     $tools_download_url     = undef,
  Stdlib::Absolutepath $tools_download_dir     = '/usr/local/src',
  Boolean              $disable_irqbalance     = false,
  Optional[String]     $device                 = undef,
  Stdlib::Absolutepath $udf_path               = '/opt/aerospike/usr/udf/lua',
  Boolean              $manage_udf             = false,
) inherits aerospike::params {
  include aerospike::irqbalance
  include aerospike::service

  if $asinstall {
    include aerospike::install
    include aerospike::config

    Class['aerospike::install'] -> Class['aerospike::config'] -> Class['aerospike::service']

    if $manage_service and $restart_on_config_change {
      Class['aerospike::config'] ~> Class['aerospike::service']
    }
  }

  if $amc_install {
    include aerospike::amc
    Class['aerospike::amc'] -> Class['aerospike::service']
  }
}
