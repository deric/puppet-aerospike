require 'spec_helper'

describe 'aerospike' do
  on_supported_os.each do |os, os_facts|
    case os
    when %r{^centos-}, %r{^oraclelinux-}, %r{^redhat-}
      expected_tag = "el#{os_facts[:os]['release']['major']}"
    when %r{^ubuntu}
      expected_tag = "ubuntu#{os_facts[:os]['release']['full']}"
    when %r{debian-}
      expected_tag = "debian#{os_facts[:os]['release']['major']}"
    end

    context "aerospike class without any parameters on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      # Tests related to the aerospike base class content
      it { is_expected.to create_class('aerospike') }
      it { is_expected.to contain_class('aerospike::install').that_comes_before('Class[aerospike::config]') }
      it { is_expected.to contain_class('aerospike::config') }
      it { is_expected.to contain_class('aerospike::service').that_subscribes_to('Class[aerospike::config]') }

      # Tests related to the aerospike::install class
      it { is_expected.to contain_class('archive') }
      it { is_expected.to contain_package('aerospike-server-community') }
      case os_facts[:os]['family']
      when 'Debian'
        ext = 'deb'
      when 'RedHat'
        ext = 'rpm'
      end
      it { is_expected.to contain_archive("/usr/local/src/aerospike-server-community-5.7.0.11-#{expected_tag}.#{ext}") }
      it { is_expected.to contain_user('root') }
      it { is_expected.to contain_group('root') }

      # Tests related to the aerospike::config class
      it do
        is_expected.to create_file('/etc/aerospike/aerospike.conf')\
          .without_content(%r{^\s*cluster \{$})\
          .without_content(%r{^\s*security \{$})\
          .without_content(%r{^\s*xdr \{$})
      end

      # Tests related to the aerospike::service class
      it { is_expected.to contain_service('aerospike').with_ensure('running') }
    end

    context "with 6.4.0.4 version on #{os}" do
      let(:facts) { os_facts }
      let(:version) { '6.4.0.4' }
      let(:target_dir) { "/usr/local/src/aerospike-server-enterprise-5.7.0.11-#{expected_tag}" }
      let(:params) do
        {
          version: version,
          remove_archive: false,
        }
      end

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('aerospike') }
      it { is_expected.to contain_class('aerospike::config') }

      it { is_expected.to contain_class('archive') }

      case os_facts[:os]['family']
      when 'Debian'
        ext = 'deb'
        it do
          is_expected.to contain_archive("/usr/local/src/aerospike-server-community-#{version}-#{expected_tag}.#{ext}")\
            .with_ensure('present')\
            .with_source("https://github.com/aerospike/aerospike-server/releases/download/#{version}/aerospike-server-community_#{version}-1#{expected_tag}_#{os_facts[:os]['architecture']}.#{ext}")\
            .with_cleanup(false)
        end
      when 'RedHat'
        ext = 'rpm'
        it do
          # e.g.
          #  https://github.com/aerospike/aerospike-server/releases/download/6.4.0.4/aerospike-server-community_6.4.0.4-1.el7.x86_64.rpm
          #  https://github.com/aerospike/aerospike-server/releases/download/6.4.0.4/aerospike-server-community-6.4.0.4-1.el7.x86_64.rpm
          is_expected.to contain_archive("/usr/local/src/aerospike-server-community-#{version}-#{expected_tag}.#{ext}")\
            .with_ensure('present')\
            .with_source("https://github.com/aerospike/aerospike-server/releases/download/#{version}/aerospike-server-community-#{version}-1.#{expected_tag}.#{os_facts[:os]['architecture']}.#{ext}")\
            .with_cleanup(false)
        end
      end

      it { is_expected.to contain_archive("/usr/local/src/aerospike-server-community-#{version}-#{expected_tag}.#{ext}") }
    end

    context "aerospike class with custom url on #{os}" do
      let(:params) do
        {
          version: '5.7.0.11',
          download_url: "http://my_fileserver.example.com/aerospike/aerospike-server-enterprise-5.7.0.11-#{expected_tag}.tgz",
          edition: 'enterprise',
        }
      end
      let(:facts) { os_facts }

      let(:target_dir) { "/usr/local/src/aerospike-server-enterprise-5.7.0.11-#{expected_tag}" }

      it { is_expected.to compile.with_all_deps }

      it do
        is_expected.to contain_archive("/usr/local/src/aerospike-server-enterprise-5.7.0.11-#{expected_tag}.tgz")\
          .with_ensure('present')\
          .with_source("http://my_fileserver.example.com/aerospike/aerospike-server-enterprise-5.7.0.11-#{expected_tag}.tgz")\
          .with_extract(true)\
          .with_extract_path('/usr/local/src')\
          .with_creates(target_dir)\
          .with_cleanup(false)\
          .that_notifies('Exec[aerospike-install-server]')
      end

      case os_facts[:os]['family']
      when 'Debian'
        it { is_expected.to contain_exec('aerospike-install-server').with_command("#{target_dir}/asinstall --force-confold -i") }
      when 'RedHat'
        it { is_expected.to contain_exec('aerospike-install-server').with_command("#{target_dir}/asinstall -Uvh") }
      end
    end

    context "aerospike class with all parameters (except custom url) on #{os}" do
      let(:version) { '6.3.0.12' }
      let(:params) do
        {
          version: version,
          download_dir: '/tmp',
          remove_archive:   true,
          edition:          'enterprise',
          download_user:    'dummy_user',
          download_pass:    'dummy_password',
          system_user:      'as_user',
          system_uid:       511,
          system_group:     'as_group',
          system_gid:       512,
          service_provider: 'init',
          config_service: {
            'paxos-single-replica-limit'    => 2,
            'pidfile'                       => '/run/aerospike/asd.pid',
            'service-threads'               => 8,
            'scan-thread'                   => 6,
            'transaction-queues'            => 2,
            'transaction-threads-per-queue' => 4,
            'proto-fd-max'                  => 20_000,
          },
          config_logging: {
            '/var/log/aerospike/aerospike.log' => ['any info'],
            '/var/log/aerospike/aerospike.debug' => ['cluster debug', 'migrate debug'],
          },
          config_net_svc: {
            'address'        => 'any',
            'port'           => 4000,
            'access-address' => '192.168.1.100',
          },
          config_net_fab: {
            'address' => 'any',
            'port'    => 4001,
          },
          config_net_inf: {
            'address' => 'any',
            'port'    => 4003,
          },
          config_net_hb: {
            'mode'                                 => 'mesh',
            'address'                              => '192.168.1.100',
            'mesh-seed-address-port 192.168.1.100' => '3002',
            'mesh-seed-address-port 192.168.1.101' => '3002',
            'mesh-seed-address-port 192.168.1.102' => '3002',
            'port'                                 => 3002,
            'interval'                             => 150,
            'timeout'                              => 10,
          },
          config_ns: {
            'bar'                  => {
              'replication-factor' => 2,
              'memory-size'        => '10G',
              'default-ttl'        => '30d',
              'storage-engine'     => 'memory',
            },
            'foo'                     => {
              'replication-factor'    => 2,
              'memory-size'           => '1G',
              'storage-engine device' => [
                'file /data/aerospike/foo.dat',
                'filesize 10G',
                'data-in-memory false',
              ],
            },
          },
          config_cluster: {
            'mode' => 'dynamic',
            'self-group-id' => 201,
          },
          config_sec: {
            'privilege-refresh-period' => 500,
            'syslog'                   => [
              'local 0',
              'report-user-admin true',
              'report-authentication true',
              'report-data-op foo true',
            ],
            'log' => [
              'report-violation true',
            ],
          },
          config_xdr: {
            'enable-xdr'         => true,
            'xdr-namedpipe-path' => '/tmp/xdr_pipe',
            'xdr-digestlog-path' => '/opt/aerospike/digestlog 100G',
            'xdr-errorlog-path'  => '/var/log/aerospike/asxdr.log',
            'xdr-pidfile'        => '/var/run/aerospike/asxdr.pid',
            'local-node-port'    => 4000,
            'xdr-info-port'      => 3004,
            'datacenter DC1'     => [
              'dc-node-address-port 172.68.17.123 3000',
            ],
          },
          config_mod_lua: {
            'user-path' => '/opt/aerospike/usr/udf/lua',
          },
          service_status: 'stopped',
        }
      end
      let(:facts) { os_facts }

      let(:target_dir) { "/tmp/aerospike-server-enterprise-#{version}-#{expected_tag}" }

      it { is_expected.to compile.with_all_deps }

      # Tests related to the aerospike base class content
      it { is_expected.to create_class('aerospike') }
      it { is_expected.to contain_class('aerospike::install').that_comes_before('Class[aerospike::config]') }
      it { is_expected.to contain_class('aerospike::config') }
      it { is_expected.to contain_class('aerospike::service').that_subscribes_to('Class[aerospike::config]') }

      case os_facts[:os]['family']
      when 'Debian'
        ext = 'deb'
        it do
          is_expected.to contain_archive("/tmp/aerospike-server-enterprise-#{version}-#{expected_tag}.#{ext}")\
            .with_ensure('present')\
            .with_username('dummy_user')\
            .with_password('dummy_password')\
            .with_source("https://github.com/aerospike/aerospike-server/releases/download/#{version}/aerospike-server-enterprise_#{version}-1#{expected_tag}_#{os_facts[:os]['architecture']}.#{ext}")\
            .with_cleanup(true)
        end
      when 'RedHat'
        ext = 'rpm'
        it do
          is_expected.to contain_archive("/tmp/aerospike-server-enterprise-#{version}-#{expected_tag}.#{ext}")\
            .with_ensure('present')\
            .with_username('dummy_user')\
            .with_password('dummy_password')\
            .with_source("https://github.com/aerospike/aerospike-server/releases/download/#{version}/aerospike-server-enterprise-#{version}-1.#{expected_tag}.#{os_facts[:os]['architecture']}.#{ext}")\
            .with_cleanup(true)
        end
      end

      it do
        is_expected.to contain_user('as_user')\
          .with_ensure('present')\
          .with_uid(511)\
          .with_gid('as_group')\
          .with_shell('/usr/sbin/nologin')
      end

      it do
        is_expected.to contain_group('as_group')\
          .with_ensure('present')\
          .with_gid(512)\
          .that_comes_before('User[as_user]')
      end

      # Tests related to the aerospike::config class
      # Especially the erb
      it do
        is_expected.to create_file('/etc/aerospike/aerospike.conf')\
          .with_content(%r{^\s*user as_user$})\
          .with_content(%r{^\s*group as_group$})\
          .with_content(%r{^\s*paxos-single-replica-limit 2$})\
          .with_content(%r{^\s*pidfile /run/aerospike/asd.pid$})\
          .with_content(%r{^\s*service-threads 8$})\
          .with_content(%r{^\s*scan-thread 6$})\
          .with_content(%r{^\s*transaction-queues 2$})\
          .with_content(%r{^\s*transaction-threads-per-queue 4$})\
          .with_content(%r{^\s*proto-fd-max 20000$})\
          .with_content(%r{^\s*file /var/log/aerospike/aerospike.log \{$})\
          .with_content(%r{^\s*context any info$})\
          .with_content(%r{^\s*file /var/log/aerospike/aerospike.debug \{$})\
          .with_content(%r{^\s*context cluster debug$})\
          .with_content(%r{^\s*context migrate debug$})\
          .with_content(%r{^\s*access-address 192.168.1.100$})\
          .with_content(%r{^\s*address any$})\
          .with_content(%r{^\s*port 4000$})\
          .with_content(%r{^\s*mode mesh$})\
          .with_content(%r{^\s*address 192.168.1.100$})\
          .with_content(%r{^\s*mesh-seed-address-port 192.168.1.100 3002$})\
          .with_content(%r{^\s*mesh-seed-address-port 192.168.1.101 3002$})\
          .with_content(%r{^\s*mesh-seed-address-port 192.168.1.102 3002$})\
          .with_content(%r{^\s*port 3002$})\
          .with_content(%r{^\s*interval 150$})\
          .with_content(%r{^\s*timeout 10$})\
          .with_content(%r{^\s*namespace bar \{$})\
          .with_content(%r{^\s*namespace foo \{$})\
          .with_content(%r{^\s*replication-factor 2$})\
          .with_content(%r{^\s*memory-size 10G$})\
          .with_content(%r{^\s*default-ttl 30d$})\
          .with_content(%r{^\s*storage-engine memory$})\
          .with_content(%r{^\s*storage-engine device \{$})\
          .with_content(%r{^\s*file /data/aerospike/foo.dat$})\
          .with_content(%r{^\s*filesize 10G$})\
          .with_content(%r{^\s*data-in-memory false$})\
          .with_content(%r{^\s*cluster \{$})\
          .with_content(%r{^\s*mode dynamic$})\
          .with_content(%r{^\s*self-group-id 201$})\
          .with_content(%r{^\s*security \{$})\
          .with_content(%r{^\s*privilege-refresh-period 500$})\
          .with_content(%r{^\s*syslog \{$})\
          .with_content(%r{^\s*local 0$})\
          .with_content(%r{^\s*report-user-admin true$})\
          .with_content(%r{^\s*report-authentication true$})\
          .with_content(%r{^\s*report-data-op foo true$})\
          .with_content(%r{^\s*log \{$})\
          .with_content(%r{^\s*report-violation true$})\
          .with_content(%r{^\s*xdr \{$})\
          .with_content(%r{^\s*enable-xdr true$})\
          .with_content(%r{^\s*xdr-namedpipe-path /tmp/xdr_pipe$})\
          .with_content(%r{^\s*xdr-digestlog-path /opt/aerospike/digestlog 100G$})\
          .with_content(%r{^\s*xdr-errorlog-path /var/log/aerospike/asxdr.log$})\
          .with_content(%r{^\s*xdr-pidfile /var/run/aerospike/asxdr.pid$})\
          .with_content(%r{^\s*local-node-port 4000$})\
          .with_content(%r{^\s*xdr-info-port 3004$})\
          .with_content(%r{^\s*datacenter DC1 \{$})\
          .with_content(%r{^\s*dc-node-address-port 172.68.17.123 3000$})\
          .with_content(%r{^\s*mod-lua \{$})\
          .with_content(%r{^\s*user-path /opt/aerospike/usr/udf/lua$})
      end

      # Tests related to the aerospike::service class
      it do
        is_expected.to contain_service('aerospike')\
          .with_ensure('stopped')\
          .with_enable(true)\
          .with_hasrestart(true)\
          .with_hasstatus(true)\
          .with_provider('init')
      end
    end

    context "aerospike class with all tools-related parameters on #{os}" do
      let(:params) do
        {
          tools_version: '3.16.0',
          tools_download_url: "https://my_fileserver.example.com/aerospike-tools/aerospike-tools-3.16.0-#{expected_tag}.tgz",
          tools_download_dir: '/tmp',
        }
      end
      let(:facts) { os_facts }

      let(:target_dir) { "/tmp/aerospike-tools-3.16.0-#{expected_tag}" }

      it { is_expected.to compile.with_all_deps }

      it do
        is_expected.to contain_archive("/tmp/aerospike-tools-3.16.0-#{expected_tag}.tgz")\
          .with_ensure('present')\
          .with_source("https://my_fileserver.example.com/aerospike-tools/aerospike-tools-3.16.0-#{expected_tag}.tgz")\
          .with_extract(true)\
          .with_extract_path('/tmp')\
          .with_creates(target_dir)\
          .with_cleanup(false)\
          .that_notifies('Exec[aerospike-install-tools]')
      end

      it { is_expected.to contain_exec('aerospike-install-tools').with_command("#{target_dir}/asinstall") }
    end
  end

  context 'aerospike class with github deb package on Debian 10' do
    let(:params) do
      {
        version: '5.7.0.16',
        target_os_tag: 'debian10',
        download_url: 'https://github.com/aerospike/aerospike-server/releases/download/5.7.0.16/aerospike-server-community-5.7.0.16.debian10.x86_64.deb',
      }
    end
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Debian',
          architecture: 'amd64',
          release: { major: '10' },
        },
      }
    end
    let(:target_file) { '/usr/local/src/aerospike-server-community-5.7.0.16-debian10.deb' }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_archive(target_file)\
        .with_ensure('present')\
        .with_source('https://github.com/aerospike/aerospike-server/releases/download/5.7.0.16/aerospike-server-community-5.7.0.16.debian10.x86_64.deb')\
        .with_extract(false)\
        .with_cleanup(false)\
        .that_notifies('Package[aerospike-server-community]')
    end

    it {
      is_expected.to contain_package('aerospike-server-community')\
        .with_ensure(%r{latest})\
        .with_source('/usr/local/src/aerospike-server-community-5.7.0.16-debian10.deb')
    }
  end

  describe 'aerospike class with github rpm package on RedHat 8' do
    let(:params) do
      {
        version: '5.7.0.16',
        target_os_tag: 'el8',
        download_url: 'https://github.com/aerospike/aerospike-server/releases/download/5.7.0.16/aerospike-server-community-5.7.0.16-1.el8.x86_64.rpm',
      }
    end
    let(:facts) do
      {
        osfamily: 'RedHat',
        os: {
          family: 'RedHat',
          name: 'RedHat',
          architecture: 'amd64',
          release: { major: '8' },
        },
      }
    end
    let(:target_file) { '/usr/local/src/aerospike-server-community-5.7.0.16-el8.rpm' }

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_archive(target_file)\
        .with_ensure('present')\
        .with_source('https://github.com/aerospike/aerospike-server/releases/download/5.7.0.16/aerospike-server-community-5.7.0.16-1.el8.x86_64.rpm')\
        .with_extract(false)\
        .with_cleanup(false)\
        .that_notifies('Package[aerospike-server-community]')
    end

    it {
      is_expected.to contain_package('aerospike-server-community')\
        .with_ensure(%r{latest})\
        .with_source('/usr/local/src/aerospike-server-community-5.7.0.16-el8.rpm')
    }
  end

  shared_examples 'supported_os' do |osfamily, dist, majrelease, _expected_tag|
    # #####################################################################
    # Test with every parameter (except the custom urls covered earlier)
    # #####################################################################

    # #####################################################################
    # Tests creating a file with XDR credentials
    # #####################################################################
    describe "try create a file with XDR credentials - defined default params on #{osfamily}" do
      let(:params) { { config_xdr_credentials: {} } }
      let(:facts) do
        {
          osfamily: osfamily,
          os: {
            family: osfamily,
            name: dist,
            architecture: 'amd64',
            release: { major: majrelease },
          },
        }
      end

      # The details of the test of Aerospike::Xdr_credentials_file define are in
      # spec/defines/xdr_credentials_file_spec.rb
      it { is_expected.not_to contain_Aerospike__Xdr_credentials_file('') }
    end

    describe "create a file with XDR credentials on #{osfamily}" do
      let(:params) { { config_xdr_credentials: { 'DC1' => { 'username' => 'xdr_user_DC1', 'password' => 'xdr_password_DC1' } } } }
      let(:facts) do
        {
          osfamily: osfamily,
          os: {
            family: osfamily,
            name: dist,
            architecture: 'amd64',
            release: { major: majrelease },
          },
        }
      end

      # The details of the test of Aerospike::Xdr_credentials_file define are in
      # spec/defines/xdr_credentials_file_spec.rb
      it { is_expected.to contain_Aerospike__Xdr_credentials_file('DC1') }
    end

    # #####################################################################
    # Tests multiple datacenter replication for a given namespace
    # #####################################################################
    describe "Tests multiple datacenter replication for a given namespace on #{osfamily}" do
      let(:params) do
        {
          config_ns: {
            'foo' => {
              'enable-xdr'            => true,
              'xdr-remote-datacenter' => ['DC1', 'DC2'],
            },
          },
          config_xdr: {
            'enable-xdr'         => true,
            'xdr-digestlog-path' => '/opt/aerospike/digestlog 100G',
            'xdr-errorlog-path'  => '/var/log/aerospike/asxdr.log',
            'xdr-pidfile'        => '/var/run/aerospike/asxdr.pid',
            'local-node-port'    => 4000,
            'xdr-info-port'      => 3004,
            'datacenter DC1'     => [
              'dc-node-address-port 172.1.1.100 3000',
            ],
            'datacenter DC2' => [
              'dc-node-address-port 172.2.2.100 3000',
            ],
          },
        }
      end
      let(:facts) do
        {
          osfamily: osfamily,
          os: {
            family: osfamily,
            name: dist,
            architecture: 'amd64',
            release: { major: majrelease },
          },
        }
      end

      it { is_expected.to compile.with_all_deps }
      it do
        is_expected.to create_file('/etc/aerospike/aerospike.conf')\
          .with_content(%r{^\s*namespace foo \{$})\
          .with_content(%r{^\s*enable-xdr true$})\
          .with_content(%r{^\s*xdr-remote-datacenter DC1$})\
          .with_content(%r{^\s*xdr-remote-datacenter DC2$})\
          .with_content(%r{^\s*xdr-digestlog-path /opt/aerospike/digestlog 100G$})\
          .with_content(%r{^\s*xdr-errorlog-path /var/log/aerospike/asxdr.log$})\
          .with_content(%r{^\s*xdr-pidfile /var/run/aerospike/asxdr.pid$})\
          .with_content(%r{^\s*local-node-port 4000$})\
          .with_content(%r{^\s*xdr-info-port 3004$})\
          .with_content(%r{^\s*datacenter DC1 \{$})\
          .with_content(%r{^\s*dc-node-address-port 172.1.1.100 3000$})\
          .with_content(%r{^\s*datacenter DC2 \{$})\
          .with_content(%r{^\s*dc-node-address-port 172.2.2.100 3000$})
      end
    end

    # #####################################################################
    # Test for the manage_service set to false
    # #####################################################################
    describe 'manage_service set to false' do
      let(:params) { { manage_service: false } }
      let(:facts) do
        {
          osfamily: osfamily,
          os: {
            family: osfamily,
            name: dist,
            architecture: 'amd64',
            release: { major: majrelease },
          },
        }
      end

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('aerospike::install').that_comes_before('Class[aerospike::config]') }
      it { is_expected.to contain_class('aerospike::config').that_comes_before('Class[aerospike::service]') }
      it { is_expected.to contain_class('aerospike::service') }
      # the service should not subscribe to the config but should be present
      it { is_expected.not_to contain_class('aerospike::service').that_subscribes_to('Class[aerospike::config]') }

      it { is_expected.not_to contain_service('aerospike') }
      # We still manage the config file
      it { is_expected.to create_file('/etc/aerospike/aerospike.conf') }
    end
  end

  context 'supported operating systems - aerospike-server-related tests' do
    # execute shared tests on various distributions
    # parameters :                  osfamily, dist, majrelease, expected_tag
    it_behaves_like 'supported_os', 'Debian', 'Debian', '10', 'debian10'
    it_behaves_like 'supported_os', 'Debian', 'Ubuntu', '20.04', 'ubuntu20.04'
    it_behaves_like 'supported_os', 'RedHat', 'RedHat', '7', 'el7'
  end

  # #####################################################################
  # Test for the restart_on_config_change set to false
  # #####################################################################
  describe 'restart_on_config_change set to false' do
    let(:params) { { restart_on_config_change: false } }
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          architecture: 'amd64',
          release: { major: '18.04' },
        },
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('aerospike::install').that_comes_before('Class[aerospike::config]') }
    it { is_expected.to contain_class('aerospike::config').that_comes_before('Class[aerospike::service]') }
    it { is_expected.to contain_class('aerospike::service') }
    # the service should not subscribe to the config but should be present
    it { is_expected.not_to contain_class('aerospike::service').that_subscribes_to('Class[aerospike::config]') }

    # That's the big difference compared to manage_service
    it { is_expected.to contain_service('aerospike') }
    # We still manage the config file
    it { is_expected.to create_file('/etc/aerospike/aerospike.conf') }
  end

  describe 'allow changing service provider' do
    let(:params) { { service_provider: 'systemd' } }
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          architecture: 'amd64',
          release: { major: '18.04' },
        },
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('aerospike::install').that_comes_before('Class[aerospike::config]') }
    it { is_expected.to contain_class('aerospike::config').that_comes_before('Class[aerospike::service]') }
    it { is_expected.to contain_class('aerospike::service') }

    it { is_expected.to contain_service('aerospike').with_hasrestart(true).with_hasstatus(true).with_provider('systemd') }
  end

  describe 'allow modifying asinstall parameters' do
    let(:params) do
      {
        version: '7.1.0.2',
        asinstall_params: '--force-confnew -i',
        download_url: 'https://github.com/aerospike/aerospike-server/archive/refs/tags/7.1.0.2.tar.gz',
      }
    end
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Debian',
          architecture: 'amd64',
          release: { major: '10' },
        },
      }
    end

    let(:target_dir) { '/usr/local/src/aerospike-server-community-7.1.0.2-debian10' }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('aerospike::install').that_comes_before('Class[aerospike::config]') }
    it { is_expected.to contain_class('aerospike::config').that_comes_before('Class[aerospike::service]') }
    it { is_expected.to create_file('/etc/aerospike/aerospike.conf') }

    it { is_expected.to contain_exec('aerospike-install-server').with_command("#{target_dir}/asinstall --force-confnew -i") }
  end

  shared_examples 'amc-related' do |osfamily, dist, majrelease|
    # Here we enforce only the amc_version as this test would be useless if we
    # change the defautl version.
    describe "aerospike class without any parameters on #{osfamily}" do
      let(:params) do
        {
          amc_version: '4.0.19',
          service_provider: 'init',
        }
      end
      let(:facts) do
        {
          osfamily: osfamily,
          os: {
            family: osfamily,
            name: dist,
            architecture: 'amd64',
            release: { major: majrelease },
          },
        }
      end

      it { is_expected.to compile.with_all_deps }

      # Tests related to the aerospike::amc class
      it { is_expected.not_to contain_archive('/usr/local/src/aerospike-amc-community-4.0.19_amd64.deb') }
      it { is_expected.not_to contain_package('aerospike-amc-community') }

      # Tests related to the aerospike::config class

      # Tests related to the aerospike::service class
      it { is_expected.not_to contain_service('amc') }
      it { is_expected.to contain_service('aerospike').with_hasrestart(true).with_hasstatus(true).with_provider('init') }
    end

    describe "aerospike class with all amc-related parameters on #{osfamily}" do
      let(:params) do
        {
          amc_install: true,
          amc_version: '4.0.19',
          amc_download_dir: '/tmp',
          amc_download_url: 'http://my_fileserver.example.com/aerospike/aerospike-amc-community-4.0.19_amd64.deb',
          amc_manage_service: true,
          amc_service_status: 'stopped',
        }
      end
      let(:facts) do
        {
          os: {
            family: osfamily,
            name: dist,
            architecture: 'amd64',
            release: { major: '8' },
          },
        }
      end

      # Tests related to the aerospike base class content
      it { is_expected.to contain_class('aerospike::amc').that_comes_before('Class[aerospike::service]') }

      # Tests related to the aerospike::amc class
      it do
        is_expected.to contain_archive('/tmp/aerospike-amc-community-4.0.19_amd64.deb')\
          .with_ensure('present')\
          .with_source('http://my_fileserver.example.com/aerospike/aerospike-amc-community-4.0.19_amd64.deb')\
          .with_extract(false)\
          .with_extract_path('/tmp')\
          .with_creates('/tmp/aerospike-amc-community-4.0.19_amd64.deb')\
          .with_cleanup(false)
      end

      it do
        is_expected.to contain_package('aerospike-amc-community')\
          .with_ensure('latest')\
          .with_provider('dpkg')\
          .with_source('/tmp/aerospike-amc-community-4.0.19_amd64.deb')
      end

      # Tests related to the aerospike::config class

      # Tests related to the aerospike::service class
      it do
        is_expected.to contain_service('amc')\
          .with_ensure('stopped')\
          .with_enable(true)\
          .with_hasrestart(true)\
          .with_hasstatus(true)
      end
    end
  end

  context 'supported operating systems - amc-related tests' do
    # execute shared tests on various distributions
    # parameters :                  osfamily, dist, majrelease
    it_behaves_like 'amc-related', 'Debian', 'Debian', '8'
    it_behaves_like 'amc-related', 'Debian', 'Ubuntu', '18.04'
  end

  describe 'disable irqbalance' do
    let(:params) { { disable_irqbalance: true } }
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Debian',
          architecture: 'amd64',
          release: { major: '9' },
        },
      }
    end

    let(:target_dir) { '/usr/local/src/aerospike-server-community-5.7.0.11-debian8' }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('aerospike::install').that_comes_before('Class[aerospike::config]') }
    it { is_expected.to contain_class('aerospike::config').that_comes_before('Class[aerospike::service]') }
    it { is_expected.to create_file('/etc/aerospike/aerospike.conf') }

    it { is_expected.to contain_service('irqbalance').with_ensure('running') }

    it {
      is_expected.to contain_file_line('irqbalance').with('path' => '/etc/default/irqbalance',
                                                          'line' => 'IRQBALANCE_ARGS="--policyscript=/etc/aerospike/irqbalance-ban.sh"')
    }
  end

  describe 'logging configuration' do
    let(:params) do
      {
        enable_logging: true,
        config_logging: {
          '/var/log/aerospike/aerospike.log' => ['any info'],
        },
      }
    end
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Debian',
          architecture: 'amd64',
          release: { major: '9' },
        },
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to create_file('/etc/aerospike/aerospike.conf')\
        .with_content(%r{^\s*logging \{$})\
        .with_content(%r{^\s*file /var/log/aerospike/aerospike.log \{$})\
        .with_content(%r{^\s*context any info$})\
        .with_content(%r{^\s*\}$})\
        .with_content(%r{^\s*\}$})
    end

    describe 'on systemd systems' do
      let(:params) do
        {
          enable_logging: true,
          config_logging: {
            'console' => ['any info'],
          },
        }
      end

      it { is_expected.to compile.with_all_deps }

      it do
        is_expected.to create_file('/etc/aerospike/aerospike.conf')\
          .with_content(%r{^\s*logging \{$})\
          .with_content(%r{^\s*console \{$})\
          .with_content(%r{^\s*context any info$})\
          .with_content(%r{^\s*\}$})\
          .with_content(%r{^\s*\}$})
      end
    end
  end

  describe 'permissions for storate device' do
    let(:params) do
      {
        system_user: 'aerospike',
        device: '/dev/sda',
      }
    end
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Debian',
          architecture: 'amd64',
          release: { major: '10' },
        },
      }
    end

    it do
      is_expected.to contain_exec('chown_data_device')\
        .with_command('chown aerospike $(realpath /dev/sda)')
    end
  end

  describe 'manage UDF directory' do
    let(:params) do
      {
        system_user: 'aerospike',
        system_group: 'aerospike',
        manage_udf: true,
      }
    end
    let(:facts) do
      {
        osfamily: 'Debian',
        os: {
          family: 'Debian',
          name: 'Debian',
          architecture: 'amd64',
          release: { major: '10' },
        },
      }
    end

    it do
      is_expected.to contain_file('/opt/aerospike/usr/udf/lua')\
        .with_ensure('directory')\
        .with_owner('aerospike')\
        .with_group('aerospike')
    end
  end
end
