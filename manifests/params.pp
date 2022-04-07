# == Class aerospike::params
#
# This class is used for determining distribution-specific configurations. All values
# can be manually overridden in main module's class `init.pp` by passing appropriate
# parameter.
#
class aerospike::params {

  # Select appropriate package for supported distribution.
  # See http://www.aerospike.com/download/
  case $facts['os']['family'] {
    'Debian': {
      case $facts['os']['name'] {
        'Debian': {
          case $facts['os']['release']['major'] {
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
            default: {
              $target_os_tag = 'debian10'
              $logging_target = 'console'
            }
          }
        }
        'Ubuntu': {
          case $facts['os']['release']['major'] {
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
      case $facts['os']['release']['major'] {
        '7': {
          $target_os_tag = 'el7'
          $logging_target = '/var/log/aerospike/aerospike.log'
        }
        '8': {
          $target_os_tag = 'el8'
          $logging_target = 'console'
        }
        default: {
          $target_os_tag = 'el8'
          $logging_target = 'console'
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
