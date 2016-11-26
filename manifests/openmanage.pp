# == Class: dell::openmanage
#
# This configures basic packages for Dell's OpenManage
#
# === Parameters
#
# [*sample_parameter*]
#
# === Variables
#
# [*sample_variable*]
#
# === Examples
#
#  class { 'dell::openmanage': }
#
class dell::openmanage (
  $idrac     = true,
  $storage   = true,
  $webserver = false,
) inherits dell::params {

  # Avoid dependency resolution problems by removing packages that dell
  # system update no longer depends on.
  #
  $python_smbios_packages = [
    'python-smbios',
    'smbios-utils-python',
    'yum-dellsysid',
  ]
  package { $python_smbios_packages:
    ensure => 'purged',
  }

  ########################################
  # Base packages and services
  ########################################
  
  $base_packages = [
    'srvadmin-omilcore',
    'srvadmin-deng',
    'srvadmin-omcommon',
    'srvadmin-omacore'
  ]
  package { $base_packages:
    ensure  => 'present',
    require => Class['dell::repos'],
  }

  case $::osfamily {
    'RedHat' : {
      if $::operatingsystemmajrelease < '7' {
        if $environment != 'vagrant' {
          service { 'dataeng':
            ensure     => 'running',
            hasrestart => true,
            hasstatus  => true,
            require    => [ Package['srvadmin-deng'] ],
          }
        }
      } else {
        exec { "IGNORE_GENERATION":
          cwd     => "/var/tmp",
          command => "mkdir -p /opt/dell/srvadmin/lib64/openmanage && touch /opt/dell/srvadmin/lib64/openmanage/IGNORE_GENERATION",
          creates => "/opt/dell/srvadmin/lib64/openmanage/IGNORE_GENERATION",
          path    => ["/bin", "/usr/bin"]
        }
        if $environment != 'vagrant' {
          service { 'dataeng':
            ensure     => 'running',
            hasrestart => true,
            hasstatus  => true,
            require    => [ Package['srvadmin-deng'], Exec['IGNORE_GENERATION'] ],
          }
        }
      }
    }
    default: {
      if $environment != 'vagrant' {
        service { 'dataeng':
          ensure     => 'running',
          hasrestart => true,
          hasstatus  => true,
          require    => Package['srvadmin-deng'],
        }
      }
    }
  }

  # OMSA 7.2 really needs IPMI to function
  case $::osfamily {
    'Debian' : {
      package { 'openipmi':
        ensure => installed,
        alias  => 'OpenIPMI',
      }
      $ipmiservice = 'openipmi'
    }
    'RedHat' : {
      package { 'OpenIPMI':
        ensure => installed,
      }
      $ipmiservice = 'ipmi'
    }
  }

  # WSMAN is used for BIOS configuration
  case $::osfamily {
    'Debian' : {
      $wsman_packages = ['curl', 'libxml2-utils', 'coreutils', 'wsl']
      ensure_packages($wsman_packages)
    }
    'RedHat' : {
      $wsman_packages = ['wsmancli']
      ensure_packages($wsman_packages)
    }
  }




  if $environment != 'vagrant' {
    service { $ipmiservice:
      ensure => running,
      enable => true,
      notify => Service['dataeng'],
      require => Package['OpenIPMI'],
    }
  }

  # For CentOS 7, this srvadmin-storage component causes the dataeng service
  # to segfault during startup.
  #
  if $::osfamily == 'RedHat' {
    if $::operatingsystemmajrelease < '7' {
      file_line { 'CentOS 7 srvadmin-storage compatibility fix':
        ensure => 'absent',
        path   => '/opt/dell/srvadmin/etc/srvadmin-storage/stsvc.ini',
        line   => 'vil7=dsm_sm_psrvil',
        notify => Service['dataeng'],
      }
    }
  }

  ########################################
  # iDRAC (default: true)
  ########################################
  $idrac_packages = [
    'srvadmin-idrac',
    'srvadmin-idrac7',
    'srvadmin-idracadm7',
  ]
  if $idrac {
    package { $idrac_packages:
      ensure  => 'present',
      require => Class['dell::repos'],
    }
  }

  ########################################
  # Storage (default: true)
  ########################################
  $storage_packages = [
    'srvadmin-storage',
    'srvadmin-storage-cli',
  ]
  if $storage {
    package { $storage_packages:
      ensure  => 'present',
      require => Class['dell::repos'],
    }
  }

  ########################################
  # Web interface (default: false)
  ########################################
  if $webserver {
    package { 'srvadmin-webserver':
      ensure  => 'present',
      require => Class['dell::repos'],
    }
  }
}
