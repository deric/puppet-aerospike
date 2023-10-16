# == Class aerospike::irqbalance
#
# This class is called from the aerospike class to manage the irqbalance for
# your aerospike cluster.
#
class aerospike::irqbalance {
  if $aerospike::disable_irqbalance {
    file_line { 'irqbalance':
      line   => 'IRQBALANCE_ARGS="--policyscript=/etc/aerospike/irqbalance-ban.sh"',
      path   => '/etc/default/irqbalance',
      notify => Service['irqbalance'],
    }

    service { 'irqbalance':
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
    }
  }
}
