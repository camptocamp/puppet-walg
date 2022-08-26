# @summary Setup full and incremental backup
#
# This class install one script for incremental backup and
# another for full backup, configure postgres archive_command
# and setup cronjob to perform full backup.
#
# @example
#   include walg::config
class walg::config {
  assert_private()

  file { '/usr/local/bin/archive_command.sh':
    content => epp('walg/archive_command.sh.epp',
      {
        'backup_fuse'   => $walg::backup_fuse,
        'backup_prefix' => $walg::backup_prefix,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/usr/local/bin/restore_command.sh':
    content => file('walg/restore_command.sh'),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/usr/local/bin/wal-g.sh':
    content => file('walg/wal-g.sh'),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/root/backup-restoration.sh':
    content => epp('walg/backup-restoration.sh.epp',
      {
        'datadir'        => $postgresql::params::datadir,
        'service_name'   => $postgresql::params::service_name,
        'version'        => $postgresql::params::version,
        'remove_archive' => $walg::backup_enable,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/root/setup-replica-from-backup.sh':
    content => epp('walg/setup-replica-from-backup.sh.epp',
      {
        'datadir'      => $postgresql::params::datadir,
        'service_name' => $postgresql::params::service_name,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/usr/local/bin/cron-full-backup.sh':
    content => epp('walg/cron-full-backup.sh.epp',
      {
        'datadir' => $postgresql::params::datadir,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/usr/local/bin/backup-fuse.sh':
    content => epp('walg/backup-fuse.sh.epp',
      {
        'backup_fuse_threshold' => $walg::backup_fuse_threshold_gbytes,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  if $walg::backup_enable {
    postgresql::server::config_entry {
      'archive_mode':
        value => 'on',
        ;
      'archive_command':
        value => '/usr/local/bin/archive_command.sh /usr/local/bin/exporter.env %p',
        ;
      'restore_command':
        value => '/usr/local/bin/restore_command.sh /usr/local/bin/exporter.env %f %p',
        ;
    }

    cron { 'full-backup':
      command => "/usr/local/bin/cron-full-backup.sh /usr/local/bin/exporter.env ${walg::retention} | logger -t walg-fullbackup",
      user    => 'root',
      hour    => $walg::cron_hour,
      minute  => $walg::cron_minute,
    }

  } else {

    postgresql::server::config_entry {
      'archive_mode':
        value => 'off',
        ;
      'archive_command':
        ensure => absent,
        ;
      'restore_command':
        ensure => absent,
        ;
    }

    cron { 'full-backup':
      ensure => absent,
    }
  }

  if $walg::backup_fuse {
    cron { 'backup-fuse':
      command     => '/usr/local/bin/backup-fuse.sh',
      environment => 'PATH=/usr/local/bin:/usr/bin:/bin',
      user        => 'postgres',
      minute      => '*/5',
    }
  }
}
