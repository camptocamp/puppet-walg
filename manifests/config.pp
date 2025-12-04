# @summary Setup full and incremental backup
#
# This class install one script for incremental backup and
# another for full backup, configure postgres archive_command
# and setup cronjob to perform full backup.
#
# @param retention How many days of postgresql backup will be kept
# @param cron_hour The backup cronjob hour
# @param cron_minute The backup cronjob minute
# @param backup_enable If enable Postgresql wal continues backup and fullbackup
# @param backup_fuse Check if the disk is almost full due to accumulating wals
# @param backup_fuse_threshold_gbytes The thredhold to trigger backup fuse
class walg::config (
  Optional[Integer]    $backup_fuse_threshold_gbytes = $walg::backup_fuse_threshold_gbytes,
  Integer              $retention                    = $walg::retention,
  Integer              $cron_hour                    = $walg::cron_hour,
  Integer              $cron_minute                  = $walg::cron_minute,
  Boolean              $backup_enable                = $walg::backup_enable,
  Boolean              $backup_fuse                  = $walg::backup_fuse,
) {
  assert_private()

  file { '/usr/local/bin/archive_command.sh':
    content => epp('walg/archive_command.sh.epp',
      {
        'backup_fuse'   => $backup_fuse,
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
        'remove_archive' => ! $backup_enable,
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

  if $backup_fuse {
    file { '/usr/local/bin/backup-fuse.sh':
      content => epp('walg/backup-fuse.sh.epp',
        {
          'backup_fuse_threshold' => $backup_fuse_threshold_gbytes,
        }
      ),
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
    }

    cron { 'backup-fuse':
      command     => '/usr/local/bin/backup-fuse.sh',
      environment => 'PATH=/usr/local/bin:/usr/bin:/bin',
      user        => 'postgres',
      minute      => '*/5',
    }
  }

  if $backup_enable {
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
      command => "/usr/local/bin/cron-full-backup.sh /usr/local/bin/exporter.env ${retention} | logger -t walg-fullbackup",
      user    => 'root',
      hour    => $cron_hour,
      minute  => $cron_minute,
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
        value => '/bin/false',
        ;
    }

    cron { 'full-backup':
      ensure => absent,
    }
  }
}
