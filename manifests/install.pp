# == Class: aerospike::install
#
# This class is called from the aerospike class to download and install an
# aerospike server
#
# == Dependencies
#
# The archive module available at:
# https://forge.puppetlabs.com/puppet/archive
#
class aerospike::install {
  include archive

  $_package_version = $aerospike::package_ensure ? {
    undef   => latest,
    default => $aerospike::package_ensure
  }

  $_server = "https://github.com/aerospike/aerospike-server/releases/download/${aerospike::version}"
  $_ext = $facts['os']['family'] ? {
    'Debian' => 'deb',
    'RedHat' => 'rpm',
    default  => 'tgz',
  }

  $_suffix = $facts['os']['family'] ? {
    'Debian' => '-1',
    'RedHat' => '-1.',
    default  => '',
  }

  $_arch = versioncmp($aerospike::version, '6.2.0.0') > 0 ? {
    true => $facts['os']['family'] ? {
      'Debian' => "_${facts['os']['architecture']}",
      'RedHat' => ".${facts['os']['architecture']}",
      default  => '',
    },
    false => '',
  }

  $src = $aerospike::download_url =~ String[1] ? {
    # https://github.com/aerospike/aerospike-server/releases/download/6.4.0.2/aerospike-server-community_6.4.0.2-1debian12_amd64.deb
    false  => $facts['os']['family'] ? {
      # debian releases contain underscore
      'Debian' => "${_server}/aerospike-server-${aerospike::edition}_${aerospike::version}${_suffix}${aerospike::target_os_tag}${_arch}.${_ext}",
      default => "${_server}/aerospike-server-${aerospike::edition}-${aerospike::version}${_suffix}${aerospike::target_os_tag}${_arch}.${_ext}",
    },
    default => $aerospike::download_url,
  }
  $dest = "${aerospike::download_dir}/aerospike-server-${aerospike::edition}-${aerospike::version}-${aerospike::target_os_tag}"

  if $aerospike::asinstall_params {
    $_asinstall_params = $aerospike::asinstall_params
  } else {
    $_asinstall_params = $facts['os']['family'] ? {
      'Debian' => '--force-confold -i',
      'RedHat' => '-Uvh',
      default  => '',
    }
  }

  # releases from github (https://github.com/aerospike/aerospike-server/releases)
  # no longer contain `asinstall` script

  # findout extension of requested file
  $src =~ /.([a-z]+)$/
  case $1 {
    'deb': {
      archive { "${dest}.deb":
        ensure   => present,
        source   => $src,
        username => $aerospike::download_user,
        password => $aerospike::download_pass,
        extract  => false,
        cleanup  => $aerospike::remove_archive,
      } ~> package { "aerospike-server-${aerospike::edition}":
        ensure   => $_package_version,
        provider => 'dpkg',
        source   => "${dest}.deb",
      }
    }
    'rpm': {
      archive { "${dest}.rpm":
        ensure   => present,
        source   => $src,
        username => $aerospike::download_user,
        password => $aerospike::download_pass,
        extract  => false,
        cleanup  => $aerospike::remove_archive,
      } ~> package { "aerospike-server-${aerospike::edition}":
        ensure   => $_package_version,
        provider => 'rpm',
        source   => "${dest}.rpm",
      }
    }
    # tar.gz
    default: {
      archive { "${dest}.tgz":
        ensure       => present,
        source       => $src,
        username     => $aerospike::download_user,
        password     => $aerospike::download_pass,
        extract      => true,
        extract_path => $aerospike::download_dir,
        creates      => $dest,
        cleanup      => $aerospike::remove_archive,
      } ~> exec { 'aerospike-install-server':
        command     => "${dest}/asinstall ${_asinstall_params}",
        cwd         => $dest,
        refreshonly => true,
      }
    }
  }

  # #######################################
  # Defining the system user and group the service will be configured on
  # #######################################
  ensure_resource( 'user', $aerospike::system_user, {
      ensure  => present,
      uid     => $aerospike::system_uid,
      gid     => $aerospike::system_group,
      shell   => '/usr/sbin/nologin',
      require => Group[$aerospike::system_group],
    }
  )

  ensure_resource('group', $aerospike::system_group, {
      ensure => present,
      gid    => $aerospike::system_gid,
    }
  )

  # #######################################
  # Installation of aerospike tools
  # #######################################
  if $aerospike::tools_version {
    if versioncmp($aerospike::tools_version, '8.0.0') > 0 {
      $download_uri = "https://download.aerospike.com/artifacts/aerospike-tools/${aerospike::tools_version}/aerospike-tools_${aerospike::tools_version}_${aerospike::target_os_tag}_${aerospike::arch}.tgz"
      $dest_tools = "${aerospike::tools_download_dir}/aerospike-tools_${aerospike::tools_version}_${aerospike::target_os_tag}_${aerospike::arch}"
    } else {
      $download_uri = "https://download.aerospike.com/artifacts/aerospike-tools/${aerospike::tools_version}/aerospike-tools-${aerospike::tools_version}-${aerospike::target_os_tag}.tgz"
      $dest_tools = "${aerospike::tools_download_dir}/aerospike-tools-${aerospike::tools_version}-${aerospike::target_os_tag}"
    }

    $src_tools = $aerospike::tools_download_url ? {
      undef   => $download_uri,
      default => $aerospike::tools_download_url,
    }

    archive { "${dest_tools}.tgz":
      ensure       => present,
      source       => $src_tools,
      username     => $aerospike::download_user,
      password     => $aerospike::download_pass,
      extract      => true,
      extract_path => $aerospike::tools_download_dir,
      creates      => $dest_tools,
      cleanup      => $aerospike::remove_archive,
    } ~> exec { 'aerospike-install-tools':
      command     => "${dest_tools}/asinstall",
      cwd         => $dest_tools,
      refreshonly => true,
    }
  }

  if $aerospike::device and $aerospike::system_user != 'root' {
    exec { 'chown_data_device':
      command => "chown ${aerospike::system_user} $(realpath ${aerospike::device})",
      path    => ['/bin', '/sbin', '/usr/bin', '/usr/sbin'],
      unless  => "stat --format '%U' $(realpath ${aerospike::device}) | grep ${aerospike::system_user}",
    }
  }

  if $aerospike::manage_udf {
    file { $aerospike::udf_path:
      ensure  => directory,
      recurse => true,
      owner   => $aerospike::system_user,
      group   => $aerospike::system_group,
    }
  }
}
