# Aerospike Puppet module

[![Tests](https://github.com/deric/puppet-aerospike/actions/workflows/test.yml/badge.svg)](https://github.com/deric/puppet-aerospike/actions/workflows/test.yml)
[![Puppet Forge latest release](https://img.shields.io/puppetforge/v/deric/aerospike.svg)](https://forge.puppetlabs.com/deric/aerospike)
[![Puppet Forge downloads](https://img.shields.io/puppetforge/dt/deric/aerospike.svg)](https://forge.puppetlabs.com/deric/aerospike)
[![Puppet Forge score](https://img.shields.io/puppetforge/f/deric/aerospike.svg)](https://forge.puppetlabs.com/deric/aerospike/scores)

## Overview

This module installs the [Aerospike](http://www.aerospike.com) NoSQL database engine and configures it.
It can optionally install the Aerospike Management Console (aka. amc) and manage the corresponding service.

## Module Description

What is this module capable of doing?

 * Download and install the Aerospike database engine in a specific version
 * Optionally download and install the Aerospike Management Console in a specific version
 * Optionally download and install specific version of the Aerospike Tools
 * Manage a specific user and group (with their corresponding fixed uid/gid) dedicated to the service
 * Manage all the contexts configurable in an Aerospike server installation
 * Manage the Aerospike database server service
 * Optionnally manage the Aerospike Management Console service

## Setup

### What aerospike affects

Files managed by the module:

* `/etc/aerospike/aerospike.conf`

### Setup Requirements

The module requires:

 * [Puppetlabs stdlib](https://github.com/puppetlabs/puppetlabs-stdlib.git)
 * [Puppet-community's archive module](https://github.com/puppet-community/puppet-archive.git)

### Beginning with aerospike

The module can be used out of the box directly, it just requires puppet-community's archive module and puppetlab's stdlib to be in your modulepath.

To install, just use the following, puppet software will take care of puling the
dependencies:

```shell
puppet module install deric/aerospike
```

If you are working on a version not coming from the forge but directly from the
github repo, here is how you can install the dependencies of the module:

```shell
puppet module install puppetlabs/stdlib
puppet module install puppet/archive
```

## Usage

Those examples include the puppet-only configuration, and the
corresponding configuration for those who use hiera (I find it more convienient for
copy/paste of a full configuration when you have both - yes, I'm lazy ;-) ).

### Using the aerospike enterprise version

In this example you will setup an installation of an aerospike server 3.8.4
enterprise version using the default namespace:

```puppet
class { 'aerospike':
  version       => '3.8.4',
  edition       => 'enterprise',
  download_user => 'myuser',
  download_pass => 'mypassword',
}
```

Or, using hiera, you just include 'aerospike' in your puppet profile and
in hiera (of course, you use eyaml and encrypt your password with it! ;-) ):

```yaml
---
aerospike::version: 3.8.4
aerospike::edition: enterprise
aerospike::download_user: myuser
aerospike::download_pass: mypassword
```

**Note:** If you plan to switch from a community installation to an enterprise
one, you will need to uninstall the aerospike-server-community and optionally
the aerospike-tools packages.

### Defining namespaces

Configuring 2 namespaces 'bar' (stored in memory) and 'foo' (store in files on
ssd devices) containing a hahaha set protected from eviction:

```puppet
class { 'aerospike':
  config_ns => {
    'bar'                  => {
      'replication-factor' => 2,
      'memory-size'        => '10G',
      'default-ttl'        => '30d',
      'storage-engine'     => 'memory',
    },
    'foo'                     => {
      'replication-factor'    => 2,
      'memory-size'           => '1G',
      'default-ttl'           => 172800,
      'high-water-disk-pct'   => 90,
      'high-water-memory-pct' => 90,
      'set hahaha'            => [ 'set-disable-eviction true', ],
      'storage-engine device' => [
        'file /data/aerospike/foo1.dat',
        'file /data/aerospike/foo2.dat',
        'filesize 10G',
        'data-in-memory false',
        'write-block-size 128K',
        'scheduler-mode noop',
      ]
    },
  },
}
```

Or, using hiera, you just include 'aerospike' in your puppet profile and in hiera:

```yaml
---
aerospike::config_ns:
  bar:
    replication-factor: 2
    memory-size: 10G
    default-ttl: 30d
    storage-engine: memory
  foo:
    replication-factor: 2
    memory-size: 1G
    default-ttl: 172800
    high-water-disk-pct: 90
    high-water-memory-pct: 90
    set hahaha:
      - set-disable-eviction true'
    storage-engine device:
      - 'file /data/aerospike/foo1.dat'
      - 'file /data/aerospike/foo2.dat'
      - 'filesize 10G'
      - 'data-in-memory false'
      - 'write-block-size 128K'
      - 'scheduler-mode noop'
```

### Installing the Aerospike Management Console

To install and the management console and have the service managed by puppet, use:

```puppet
class { 'aerospike':
  amc_install        => true,
  amc_manage_service => true,
}
```

Or, using hiera, you just include 'aerospike' in your puppet profile and in hiera:

```yaml
---
aerospike::amc_install: true
aerospike::amc_manage_service: true
```

### Installing specific version of the Aerospike Tools

To install specific version of the Aerospike Tools, use:

```puppet
class { 'aerospike':
  tools_version => '3.16.0',
}
```

Or, using hiera, you just include 'aerospike' in your puppet profile and in hiera:

```yaml
---
aerospike::tools_version: '3.16.0'
```

### Configuring a rack-aware cluster

In this example we will be configuring a 3 nodes rack-aware cluster in a
non-multicast environment like in most cloud provider environments (so
using Mesh heartbeats). The cluster group id is a totally arbitrary choice.

In this example, the servers IP are 192.168.1.100, 192.168.1.101 and 192.168.1.102

**Note:** You will need aerospike 3.7.0 or higher to support some of those parameters.

```puppet
class { 'aerospike':
  config_service => {
    'paxos-single-replica-limit'    => 1,
    'pidfile'                       => '/var/run/aerospike/asd.pid',
    'service-threads'               => 4,
    'transaction-queues'            => 4,
    'transaction-threads-per-queue' => 4,
    'proto-fd-max'                  => 15000,
    'paxos-protocol'                => 'v4',
    'paxos-recovery-policy'         => 'auto-reset-master',
  },
  config_net_hb => {
    'mode'                                 => 'mesh',
    'address'                              => 'any',
    'port'                                 => 3002,
    'mesh-seed-address-port 192.168.1.100' => 3002,
    'mesh-seed-address-port 192.168.1.101' => 3002,
    'mesh-seed-address-port 192.168.1.102' => 3002,
    'interval'                             => 150,
    'timeout'                              => 20,
  },
  config_cluster => {
    'mode'          => 'dynamic',
    'self-group-id' => 666,
  },
}
```

Which would result in the following hiera configuration:

```yaml
---
aerospike::config_service:
  paxos-single-replica-limit: 1
  pidfile: /var/run/aerospike/asd.pid
  service-threads: 4
  transaction-queues: 4
  transaction-threads-per-queue: 4
  proto-fd-max: 15000
  paxos-protocol: v4
  paxos-recovery-policy: auto-reset-master
aerospike::config_net_hb:
  mode: mesh
  address: any
  port: 3002
  'mesh-seed-address-port 192.168.1.100': 3002
  'mesh-seed-address-port 192.168.1.101': 3002
  'mesh-seed-address-port 192.168.1.102': 3002
  interval: 150
  timeout: 20
aerospike::config_cluster:
  mode: dynamic
  self-group-id: 666
```

### Defining credentials for XDR

To define credentials of remote cluster(s) for XDR in a separate secured file
'/etc/aerospike/security-credentials\_$DC\_name.txt', use:

```puppet
class { 'aerospike':
  config_xdr_credentials => {"DC1"=>{"username"=>"xdr_user_DC1", "password"=>"xdr_password_DC1"}},
}
```

Or, using hiera, you just include 'aerospike' in your puppet profile and in hiera:

```yaml
---
aerospike::config_xdr_credentials:
  DC1:
    username: 'xdr_user_DC1'
    password: 'xdr_password_DC1'
```

### Full real-life multi-datacenter replication example for XDR with security enabled

Note that this example requires you to run at least aerospike 3.8.1.

To define a XDR replication over a namespace to multiple datacenters, you can
work based on the following example (note that it is based on a real-life prod example.
Of course, IP and other security-sensitive informations here are fake or removed):

```puppet
class { 'aerospike':
  version        => '3.8.4',
  config_service => {
    'paxos-single-replica-limit'    => 1,
    'pidfile'                       => '/var/run/aerospike/asd.pid',
    'service-threads'               => 4,
    'transaction-queues'            => 4,
    'transaction-threads-per-queue' => 4,
    'proto-fd-max'                  => 15000,
    'paxos-protocol'                => 'v4',
    'paxos-recovery-policy'         => 'auto-reset-master',
    'migrate-threads'               => 2,
  },
  config_logging => {
    '/var/logs/aerospike.log' => [ 'any info' ],
  },
  config_net_hb => {
    'mode'                              => 'mesh',
    'address'                           => 'any',
    'port'                              => 3002,
    'mesh-seed-address-port 10.0.0.101' => 3002,
    'mesh-seed-address-port 10.0.0.102' => 3002,
    'mesh-seed-address-port 10.0.0.103' => 3002,
    'mesh-seed-address-port 10.0.0.104' => 3002,
    'mesh-seed-address-port 10.0.0.105' => 3002,
    'mesh-seed-address-port 10.0.0.106' => 3002,
    'mesh-seed-address-port 10.0.0.107' => 3002,
    'mesh-seed-address-port 10.0.0.108' => 3002,
    'mesh-seed-address-port 10.0.0.109' => 3002,
    'mesh-seed-address-port 10.0.0.110' => 3002,
    'mesh-seed-address-port 10.0.0.111' => 3002,
    'mesh-seed-address-port 10.0.0.112' => 3002,
    'mesh-seed-address-port 10.0.0.113' => 3002,
    'mesh-seed-address-port 10.0.0.114' => 3002,
    'mesh-seed-address-port 10.0.0.115' => 3002,
    'mesh-seed-address-port 10.0.0.116' => 3002,
    'mesh-seed-address-port 10.0.0.117' => 3002,
    'mesh-seed-address-port 10.0.0.118' => 3002,
    'mesh-seed-address-port 10.0.0.119' => 3002,
    'mesh-seed-address-port 10.0.0.120' => 3002,
    'interval'                          => 150,
    'timeout'                           => 20,
  },
  config_cluster => {
    'mode'          => 'dynamic',
    'self-group-id' => 666,
  },
  config_ns => {
    'replicatedns'          => {
    'enable-xdr'            => 'true',
    'xdr-remote-datacenter' => [ 'DC1', 'DC2' ],
    'replication-factor'    => 2,
    'memory-size'           => '100G',
    'default-ttl'           => '30D',
    'high-water-disk-pct'   => 55,
    'high-water-memory-pct' => 65,
    'storage-engine device' => [
      'device /dev/xvdb /dev/xvdf',
      'device /dev/xvdc /dev/xvdg',
      'data-in-memory false',
      'write-block-size 1024K',
      'scheduler-mode noop',
      'defrag-lwm-pct 55',
      ],
    },
  },
  config_sec => {
    'enable-security' => 'true',
  },
  config_xdr => {
    'enable-xdr' => 'true',
    'xdr-digestlog-path' => '/mnt/aerospike-digestlog 100G',
    'xdr-ship-bins' => 'true',
    'datacenter DC1' => [
      'dc-node-address-port 192.168.1.100 3000',
      'dc-node-address-port 192.168.1.101 3000',
      'dc-node-address-port 192.168.1.102 3000',
      'dc-node-address-port 192.168.1.103 3000',
      'dc-node-address-port 192.168.1.104 3000',
      'dc-node-address-port 192.168.1.105 3000',
      'dc-node-address-port 192.168.1.106 3000',
      'dc-node-address-port 192.168.1.107 3000',
      'dc-use-alternate-services true',
      'dc-security-config-file /etc/aerospike/security-credentials_DC1.txt'
    ],
    'datacenter DC2' => [
      'dc-node-address-port 193.168.2.100 3000',
      'dc-node-address-port 192.168.2.102 3000',
      'dc-node-address-port 192.168.2.103 3000',
      'dc-node-address-port 192.168.2.104 3000',
      'dc-node-address-port 192.168.2.105 3000',
      'dc-node-address-port 192.168.2.106 3000',
      'dc-node-address-port 192.168.2.107 3000',
      'dc-node-address-port 192.168.2.108 3000',
      'dc-use-alternate-services true',
      'dc-security-config-file /etc/aerospike/security-credentials_DC2.txt'
    ],
  },
  config_xdr_credentials => {
    'DC1' => {
      'username' => 'svc_xdr_dc1',
      'password' => 'password_encrypted_with_eyaml_goes_there',
    },
    'DC2' => {
      'username' => 'svc_xdr_dc2',
      'password' => 'password_encrypted_with_eyaml_goes_there',
    },
  }
}
```

Or, using hiera, you just include 'aerospike' in your puppet profile and in hiera:

```yaml
---
aerospike::version: 3.8.4
aerospike::config_service:
  paxos-single-replica-limit: 1
  pidfile: /var/run/aerospike/asd.pid
  service-threads: 4
  transaction-queues: 4
  transaction-threads-per-queue: 4
  proto-fd-max: 15000
  paxos-protocol: v4
  paxos-recovery-policy: auto-reset-master
  migrate-threads: 2
aerospike::config_logging:
  '/var/logs/aerospike.log': [ 'any info' ]
aerospike::config_net_hb:
  mode: mesh
  address: any
  port: 3002
  'mesh-seed-address-port 10.0.0.101': 3002
  'mesh-seed-address-port 10.0.0.102': 3002
  'mesh-seed-address-port 10.0.0.103': 3002
  'mesh-seed-address-port 10.0.0.104': 3002
  'mesh-seed-address-port 10.0.0.105': 3002
  'mesh-seed-address-port 10.0.0.106': 3002
  'mesh-seed-address-port 10.0.0.107': 3002
  'mesh-seed-address-port 10.0.0.108': 3002
  'mesh-seed-address-port 10.0.0.109': 3002
  'mesh-seed-address-port 10.0.0.110': 3002
  'mesh-seed-address-port 10.0.0.111': 3002
  'mesh-seed-address-port 10.0.0.112': 3002
  'mesh-seed-address-port 10.0.0.113': 3002
  'mesh-seed-address-port 10.0.0.114': 3002
  'mesh-seed-address-port 10.0.0.115': 3002
  'mesh-seed-address-port 10.0.0.116': 3002
  'mesh-seed-address-port 10.0.0.117': 3002
  'mesh-seed-address-port 10.0.0.118': 3002
  'mesh-seed-address-port 10.0.0.119': 3002
  'mesh-seed-address-port 10.0.0.120': 3002
  interval: 150
  timeout: 20
aerospike::config_cluster:
  mode: dynamic
  self-group-id: 666
aerospike::config_ns:
  replicatedns:
    enable-xdr: true
    xdr-remote-datacenter:
      - DC1
      - DC2
    replication-factor: 2
    memory-size: 100G
    default-ttl: 30D
    high-water-disk-pct: 55
    high-water-memory-pct: 65
    storage-engine device:
      - 'device /dev/xvdb /dev/xvdf'
      - 'device /dev/xvdc /dev/xvdg'
      - 'data-in-memory false'
      - 'write-block-size 1024K'
      - 'scheduler-mode noop'
      - 'defrag-lwm-pct 55'
aerospike::config_sec:
  enable-security: true
aerospike::config_xdr:
  enable-xdr: true
  xdr-digestlog-path: '/mnt/aerospike-digestlog 100G'
  xdr-ship-bins: true
  'datacenter DC1':
    - 'dc-node-address-port 192.168.1.100 3000'
    - 'dc-node-address-port 192.168.1.101 3000'
    - 'dc-node-address-port 192.168.1.102 3000'
    - 'dc-node-address-port 192.168.1.103 3000'
    - 'dc-node-address-port 192.168.1.104 3000'
    - 'dc-node-address-port 192.168.1.105 3000'
    - 'dc-node-address-port 192.168.1.106 3000'
    - 'dc-node-address-port 192.168.1.107 3000'
    - 'dc-use-alternate-services true'
    - 'dc-security-config-file /etc/aerospike/security-credentials_DC1.txt'
  'datacenter DC2':
    - 'dc-node-address-port 192.168.2.100 3000'
    - 'dc-node-address-port 192.168.2.102 3000'
    - 'dc-node-address-port 192.168.2.103 3000'
    - 'dc-node-address-port 192.168.2.104 3000'
    - 'dc-node-address-port 192.168.2.105 3000'
    - 'dc-node-address-port 192.168.2.106 3000'
    - 'dc-node-address-port 192.168.2.107 3000'
    - 'dc-node-address-port 192.168.2.108 3000'
    - 'dc-use-alternate-services true'
    - 'dc-security-config-file /etc/aerospike/security-credentials_DC2.txt'
aerospike::config_xdr_credentials:
  DC1:
    username: svc_xdr_dc1
    password: password_encrypted_with_eyaml_goes_there
  DC2:
    username: svc_xdr_dc2
    password: password_encrypted_with_eyaml_goes_there
```

Note that if you are only doing xdr to 1 datacenter, you can use a string
instead of an array for the `xdr-remote-datacenter` parameter:

```yaml
    xdr-remote-datacenter: DC1
```

### Not restarting the service

There are 2 solutions for that. The most common usage for that would be the 1st
solution proposed.

#### Not restarting when a config is changed

To still having puppet start or stop the service as you defined but not restart
the service when a configuration is changed, set the `restart_on_config_change` parameter to `false`.

This is the method you will want to choose if you are changing dynamic
parameters with the `asinfo` or `asadm` command-line tools and that you change
the config file just to avoid problems on next restart.

Note that this won't restart the service when credentials are modified either.

```puppet
class { 'aerospike':
  restart_on_config_change => false,
}
```

Or via hiera:

```yaml
aerospike:
  restart_on_config_change: false
```

#### Not managing the service with puppet at all

To do that you define the `manage_service` parameter to `false` but keep in mind
that if there's a problem and the service goes down, puppet won't restart it.

Puppet won't restart the service if there's a config change either.

```puppet
class { 'aerospike':
  manage_service => false,
}
```

Or via hiera:

```yaml
aerospike:
  manage_service: false
```


## Reference

### Public classes

 * [`aerospike`](#class-aerospike): Installs and configures Aerospike server and the management console.

### Private classes and defines

 * `aerospike::install`: Installs Aerospike server and the management console.
 * `aerospike::config`: Configures Aerospike server and the management console.
 * `aerospike::service`: Manages the Aerospike server and the management console services.
 * `aerospike::xdr_credentials_file`: manages the credential files for xdr.


### Parameters

#### Class aerospike

##### `asinstall`

If set to false, this won't download and install the aerospike server package. Useful if need install only AMC.

Default: `true`

##### `version`

Version of the aerospike database engine to install.

Default: `3.8.4`

##### `download_dir`

Directory where to download the archive before unpacking it.

Default: `/usr/local/src`

##### `download_url`

URL from where to download the tarball. Only populate it if you want the
package to be downloaded from somewhere else than the aerospike website.

**Note:** It is mandatory to keep the name of the target file set to the
following pattern when using this custom url:
`aerospike-server-${aerospike::edition}-${aerospike::version}-${aerospike::target_os_tag}.tgz`

Default: `http://www.aerospike.com/artifacts/aerospike-server-${aerospike::edition}/${aerospike::version}/aerospike-server-${aerospike::edition}-${aerospike::version}-${aerospike::target_os_tag}.tgz`

##### `remove_archive`

Whether to remove the tarball once extracted for the aerospike server part.
Is also used for the amc when downloading a tarball (not for the deb
package).

Default: `false`

##### `edition`

The edition to use (enterprise or community).

Default: `community`

##### `target_os_tag`

Tag used in the target file name to identify the distribution package to use.

Default: `ubuntu18.04`

##### `download_user`

Username to use to download the enterprise version of the package. This is
used for both the download of the aerospike server package and the amc. This
parameter is not necessary when downloading the community version from the
aerospike repositories but you can use it if you download from a
password-protected custom url.

Default: `undef`

##### `download_pass`

Password to use to download the enterprise version of the package to use.
It is used for both the download of the aerospike server package and the amc.

Default: `undef`

##### `system_user`

OS user that the service will use in the service configuration.
This user will only be defined if not already defined somewhere else in your
Puppet catalog.

Default: `root`

##### `system_uid`

UID of the OS user to be used by the service.

Default: `undef` (number is assigned by the OS)

##### `system_group`

OS group that the service will use in the service configuration.
This group will only be defined if not already defined somewhere else in your
Puppet catalog.

Default: `root`

##### `system_gid`

GID of the OS user to be used by the service.

Default: `undef` (number is assigned by the OS)

##### `manage_service`

Boolean indicating whether you want to manage the service status or not.
If set to false, the `service_status` parameter will be ignored but the service
will still be configured.

Default: `true`

##### `service_provider`

String defining mechanism for managing service. See [Puppet docs](https://docs.puppet.com/puppet/latest/types/service.html#service-attribute-provider) for supported values.

Default: `undef` (Puppet will determine appropriate value)

##### `restart_on_config_change`

Boolean indicating whether or not you want to restart the aerospike service
whenever there's a change in the configuration files or credential files.

Note that it is different from `manage_service` because the service will still
be managed by puppet if you set it to `false` (as long as `manage_service` is set
to `true`), so if the service goes down, puppet will still take care of
restarting it.

Default: `true`

##### `config_service`

Configuration parameters to define in the service context of the aerospike
configuration file.

This parameter is a hash table with:
  * the property name as key
  * the property value as value

**Note:** The user and group are already defined by the system_user and system_group parameters.
No need to specify them again.

The default value is:

```
{
  'paxos-single-replica-limit'    => 1,
  'pidfile'                       => '/var/run/aerospike/asd.pid',
  'service-threads'               => 4,
  'transaction-queues'            => 4,
  'transaction-threads-per-queue' => 4,
  'proto-fd-max'                  => 15000,
}
```

Which generates the following configuration for the service context:

```
service {
  user root
  group root
  paxos-single-replica-limit 1
  pidfile /var/run/aerospike/asd.pid
  proto-fd-max 15000
  service-threads 4
  transaction-queues 4
  transaction-threads-per-queue 4
}
```

For more information, check the properties declared as in the "service"
context in http://www.aerospike.com/docs/reference/configuration/

##### `config_logging`

Configuration parameters to define in the logging context of the aerospike
configuration file.

This parameter is a hash table with:
    * the log file path as key (Reminder: Log file must be an absolute path.)
    * an array with the definition of all the contexts definitions as value

The default value is:

```yaml
aerospike::config_logging:
  '/var/log/aerospike/aerospike.log':
    - any detail
```

Which generates the following configuration for the logging context:

```
logging {
  file /var/log/aerospike/aerospike.log {
    context any info
  }
}
```

For systemd based system, the logs by default are configured to go to the console:

```yaml
aerospike::config_logging:
  console:
    - any detail
```

Which generates following configuration:
```
logging {
    console {
        context any info
    }
}
```

For more information about logging management in aerospike, check [the documentation](http://www.aerospike.com/docs/operations/configure/log/).


##### `config_mod_lua`

Configuration parameters for `mod-lua` context.

This parameter is a hash which is empty by default.

```
{
  'config_mod_lua' => {
    'user-path' => '/opt/aerospike/usr/udf/lua'
  },
}
```

Which generates the following configuration for the `mod-lua` context:

```
mod-lua {
    user-path /opt/aerospike/usr/udf/lua
}
```

##### `config_net_svc`

Configuration parameters to define in the service sub-stanza in the network
context of the aerospike configuration file.

This parameter is a hash table with:
  * the property name as key
  * the property value as value

Default:

```
{
  'address' => 'any',
  'port'    => 3000,
}
```

For more information about this sub-stanza:
http://www.aerospike.com/docs/operations/configure/network/general/

##### `config_net_fab`

Configuration parameters to define in the fabric sub-stanza in the network
context of the aerospike configuration file.

This parameter is a hash table with:
  * the property name as key
  * the property value as value

Default:

```
{
  'address' => 'any',
  'port'    => 3001,
}
```

For more information about this sub-stanza:
http://www.aerospike.com/docs/operations/configure/network/general/

##### `config_net_inf`

Configuration parameters to define in the info sub-stanza in the network
context of the aerospike configuration file.

This parameter is a hash table with:
  * the property name as key
  * the property value as value

Default:

```
{
  'address' => 'any',
  'port'    => 3003,
}
```

For more information about this sub-stanza:
http://www.aerospike.com/docs/operations/configure/network/general/

##### `config_net_hb`

Configuration parameters to define in the heartbeat sub-stanza in the
network context of the aerospike configuration file.

This parameter is a hash table with:
  * the property name as key
  * the property value as value

**IMPORTANT:** for declaring mesh-seed-address-port, you will need to use the `'mesh-seed-address-port <IP Address>'` as a key if you want it to work.
See [Configuring a rack-aware cluster](#configuring-a-rack-aware-cluster) for an example using this.

Default:

```
{
  'mode'     => 'multicast',
  'address'  => 'any',
  'port'     => 9918,
  'interval' => 150,
  'timeout'  => 10,
}
```

For more information about the heartbeat sub-stanza:
http://www.aerospike.com/docs/operations/configure/network/heartbeat/

##### `config_ns`

Configuration parameters to define the namespaces contexts in the aerospike
configuration file.

This parameter is a hash table with:
  * the namespace name as key
  * the value is another hash table composed by:
    - the name of the property as key
    - the value of the property as value.

When defining a sub-stanza in it for a property as you do for a
storage-engine device, you have to concatenante the property and the value
as the key (for example: "storage-engine device") and set the value as an
array, each item of the array being a line of configuration that you want to
have defined as-is in your sub-stanza. Check the example section of this
file for a more concrete example.

Default:

```
{
  'foo'                     => {
    'replication-factor'    => 2,
    'memory-size'           => '1G',
    'storage-engine device' => [
      'file /data/aerospike/data1.dat',
      'file /data/aerospike/data2.dat',
      'filesize 10G',
      'data-in-memory false',
     ]
  },
}
```

**Note:** This module won't create the path to your data files. This path must
exist. If not, aerospike won't start. In this example, you have to ensure of the
existence of your /data/aerospike directory in your profile.

For more details on the properties you can define on the namespace context,
check: http://www.aerospike.com/docs/reference/configuration/

##### `config_cluster`

Configuration parameters to define the cluster context in the aerospike
configuration file.

This parameter is a hash table with:
  * the property name as key
  * the property value as value

Default: `{}`

For more information on how to define a rack-aware cluster, see:
http://www.aerospike.com/docs/operations/configure/network/rack-aware/

##### `config_sec`

Configuration parameters to define the security context in the aerospike
configuration file.

This parameter is a hash table with:
  * the property name as key
  * the value of the property as value.

**Note:** When defining a subcontext in it for a property as you do for the
syslog or log subcontexts, set the subcontext name as the key and the
value will be an array with each item of the array being a full line
of configuration.

Default: `{}`

##### `config_xdr`

Configuration parameters to define the xdr context in the aerospike
configuration file (for cross-datacenter replication).

This parameter is a hash table with:
  * the property name as key
  * the value of the property as value.

**Note:** When defining a subcontext in it for a property as you do for the
datacenter subcontext, set the subcontext name as the key and the
value will be an array with each item of the array being a full line
of configuration.

Default: `{}`

For more informations about configuring xdr, check:
http://www.aerospike.com/docs/operations/configure/cross-datacenter/

##### `config_xdr_credentials`

Configuration parameters to define the xdr credentials (user/password) for the remote cluster in the
separate secured file when security enabled.

This parameter is a hash table with:
  * the property name as key
  * the value of the property as value.

**Note:** When defining a subcontext in it for a property as you do for the
defining the name of datacenter subcontext, set the subcontext name as the key and the
value will be a hash table with the property name (username/password) as key and the value
of the property as value.

Default: `{}`

For more informations about configuring xdr when security enabled, check:
http://www.aerospike.com/docs/operations/configure/cross-datacenter/

##### `service_status`

Controls the status of the service ("ensure" attribute in the puppet service
declaration).

Default: `running`

##### `amc_install`

If set to true, this will download and install the amc console package.

Default: `false`

##### `amc_version`

Sets which version of the amc package to install.

Default: `4.0.19`

##### `amc_download_dir`

Directory used to download the amc package.

Default: `/usr/local/src`

##### `amc_download_url`

URL from which to download the amc package. Only populate it if you want the
package to be downloaded from somewhere else than the aerospike website.

**Note:** It is mandatory to keep the name of the target file set to the
same pattern as the original name when using this custom url aka:
`aerospike-amc-${aerospike::edition}-${amc_version}${amc_pkg_extension}`

The default url is:

```
http://www.aerospike.com/artifacts/aerospike-amc-${aerospike::edition}/${amc_version}/aerospike-amc-${aerospike::edition}-${amc_version}${amc_pkg_extension}
```

##### `amc_manage_service`

Boolean that defines if you want to control the amc service via puppet or not.

Default: `false`

##### `amc_service_status`

Controls the status of the management console service ("ensure" attribute in
the puppet service declaration).

Default: `running`

##### `amc_service_enable`

Boolean indicating whether you want to manage the service status or not.

Default: `true`

##### `tools_version`

Sets which version of the "tools" package to install. If not specified, "tools" will be installed from Aerospike Server package.

Default: `undef`

##### `tools_download_url`

URL from which to download the "tools" package. Only populate it if you want the
package to be downloaded from somewhere else than the aerospike website.

**Note:** It is mandatory to keep the name of the target file set to the
same pattern as the original name when using this custom url aka:
`aerospike-tools-${aerospike::tools_version}-${aerospike::target_os_tag}`

The default url is:

```
https://www.aerospike.com/artifacts/aerospike-tools/${aerospike::tools_version}/aerospike-tools-${aerospike::tools_version}-${aerospike::target_os_tag}.tgz
```

##### `tools_download_dir`

Directory used to download the "tools" package.

Default: `/usr/local/src`

##### Configuration file generated by default

The default parameters generates the following aerospike configuration file:

```
# Aerospike database configuration file.

# service context definition
service {
  user root
  group root
  paxos-single-replica-limit 1
  pidfile /var/run/aerospike/asd.pid
  proto-fd-max 15000
  service-threads 4
  transaction-queues 4
  transaction-threads-per-queue 4
}

# logging context definition
logging {
  file /var/log/aerospike/aerospike.log {
    context any info
  }
}

# network context definition
network {
  service {
    address any
    port 3000
  }

  fabric {
    address any
    port 3001
  }

  info {
    address any
    port 3003
  }

  heartbeat {
    address any
    interval 150
    mode multicast
    port 9918
    timeout 10
  }
}

namespace foo {
  memory-size 1G
  replication-factor 2
  storage-engine device {
    data-in-memory false
    file /data/aerospike/data1.dat
    file /data/aerospike/data2.dat
    filesize 10G
  }
}
```

## Limitations

This module has only been tested against Ubuntu 14.04 - 18.04, but it should work with
the Debian and the Red Hat family.

## Development

See the [CONTRIBUTING.md](https://github.com/tubemogul/puppet-aerospike/blob/master/CONTRIBUTING.md) file.

