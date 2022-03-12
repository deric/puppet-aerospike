# == Class aerospike::params
#
# This class is used for determining distribution-specific configurations. All values
# can be manually overridden in main module's class `init.pp` by passing appropriate
# parameter.
#
class aerospike::params {

  # Select appropriate package for supported distribution.
  # See http://www.aerospike.com/download/
  case $::osfamily {
    'Debian': {
      case $::operatingsystem {
        'Debian': {
          case $::operatingsystemmajrelease {
            '7': {
              $target_os_tag = 'debian7'
              $logging_target = '/var/log/aerospike/aerospike.log'
            }
            '8': {
              $target_os_tag = 'debian8'
              $logging_target = '/var/log/aerospike/aerospike.log'
            }
            '9': {
              $target_os_tag = 'debian9'
              $logging_target = 'console'
            }
            '10': {
              $target_os_tag = 'debian10'
              $logging_target = 'console'
            }
            '11': {
              $target_os_tag = 'debian11'
              $logging_target = 'console'
            }
            default: {
              $target_os_tag = 'debian10'
              $logging_target = 'console'
            }
          }
        }
        'Ubuntu': {
          case $::operatingsystemmajrelease {
            '12.04': {
              $target_os_tag = 'ubuntu12.04'
              $logging_target = '/var/log/aerospike/aerospike.log'
            }
            '14.04': {
              $target_os_tag = 'ubuntu14.04'
              $logging_target = '/var/log/aerospike/aerospike.log'
            }
            '16.04': {
              $target_os_tag = 'ubuntu16.04'
              $logging_target = '/var/log/aerospike/aerospike.log'
            }
            '18.04': {
              $target_os_tag = 'ubuntu18.04'
              $logging_target = '/var/log/aerospike/aerospike.log'
            }
            '20.04': {
              $target_os_tag = 'ubuntu18.04'
              $logging_target = 'console'
            }
            default: {
              $target_os_tag = 'ubuntu18.04'
              $logging_target = 'console'
            }
          }
        }
        default: {
          $target_os_tag = undef
          $logging_target = $logging_target = 'console'
        }
      }
    }
    'Redhat': {
      case $::operatingsystemmajrelease {
        '6': {
          $target_os_tag = 'el6'
          $logging_target = '/var/log/aerospike/aerospike.log'
        }
        '7': {
          $target_os_tag = 'el7'
          $logging_target = '/var/log/aerospike/aerospike.log'
        }
        default: {
          $target_os_tag = 'el7'
          $logging_target = '/var/log/aerospike/aerospike.log'
        }
      }

    }
    default: {
      $target_os_tag = undef
      $logging_target = 'console'
    }
  }

  $config_logging = {
    $logging_target => [ 'any info', ],
  }

}
