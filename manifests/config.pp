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

  file { '/root/backup-restoration.sh':
    content => epp('walg/backup-restoration.sh.epp',
      {
        'datadir'      => $postgresql::params::datadir,
        'service_name' => $postgresql::params::service_name,
        'version'      => $postgresql::params::version,
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


  postgresql::server::config_entry {
    'archive_mode':
      value => 'on',
      ;

    'archive_command':
      value => '/usr/local/bin/archive_command.sh /usr/local/bin/exporter.env %p',
      ;
  }

  cron { 'full-backup':
    command => "/usr/local/bin/cron-full-backup.sh /usr/local/bin/exporter.env ${walg::retention} | logger -t walg-fullbackup",
    user    => 'root',
    hour    => 2,
    minute  => 20,
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
