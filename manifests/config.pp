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
# @param pause_archive_on_disk_pressure Check if the disk is almost full due to accumulating wals
# @param pause_archive_on_disk_pressure_threshold_gbytes The threshold to trigger archive pause
# @param pause_archive_on_disk_pressure_alert_file The alert file generated when archive is paused
# @param bin_path The walg binary destination path
# @param walg_env_file The walg environment variables file path
class walg::config (
  Optional[Integer]    $pause_archive_on_disk_pressure_threshold_gbytes = $walg::pause_archive_on_disk_pressure_threshold_gbytes,
  Stdlib::Absolutepath $pause_archive_on_disk_pressure_alert_file       = '/tmp/failed_pg_archive',
  Integer              $retention                                       = $walg::retention,
  Integer              $cron_hour                                       = $walg::cron_hour,
  Integer              $cron_minute                                     = $walg::cron_minute,
  Boolean              $backup_enable                                   = $walg::backup_enable,
  Boolean              $pause_archive_on_disk_pressure                  = $walg::pause_archive_on_disk_pressure,
  Stdlib::Absolutepath $bin_path                                        = $walg::destination,
  Stdlib::Absolutepath $walg_env_file                                   = $walg::walg_env_file,
) {
  assert_private()

  file { "${bin_path}/archive_command.sh":
    content => epp('walg/archive_command.sh.epp',
      {
        'pause_archive_on_disk_pressure'            => $pause_archive_on_disk_pressure,
        'pause_archive_on_disk_pressure_alert_file' => $pause_archive_on_disk_pressure_alert_file,
        'bin_path'                                  => $bin_path,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { "${bin_path}/restore_command.sh":
    content => epp('walg/restore_command.sh.epp',
      {
        'bin_path' => $bin_path,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { "${bin_path}/wal-g.sh":
    content => epp('walg/wal-g.sh.epp',
      {
        'bin_path'      => $bin_path,
        'walg_env_file' => $walg_env_file,
      }
    ),
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
        'bin_path'       => $bin_path,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/root/setup-replica-from-backup.sh':
    content => epp('walg/setup-replica-from-backup.sh.epp',
      {
        'datadir'        => $postgresql::params::datadir,
        'service_name'   => $postgresql::params::service_name,
        'bin_path'       => $bin_path,
        'walg_env_file'  => $walg_env_file,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { "${bin_path}/cron-full-backup.sh":
    content => epp('walg/cron-full-backup.sh.epp',
      {
        'datadir'  => $postgresql::params::datadir,
        'bin_path' => $bin_path,
      }
    ),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  if $pause_archive_on_disk_pressure {
    file { "${bin_path}/pause-archive-on-disk-pressure.sh":
      content => epp('walg/pause-archive-on-disk-pressure.sh.epp',
        {
          'pause_archive_on_disk_pressure_threshold'  => $pause_archive_on_disk_pressure_threshold_gbytes,
          'pause_archive_on_disk_pressure_alert_file' => $pause_archive_on_disk_pressure_alert_file,
        }
      ),
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
    }

    cron { 'pause-archive-on-disk-pressure':
      command     => "${bin_path}/pause-archive-on-disk-pressure.sh",
      environment => "PATH=${bin_path}:/usr/bin:/bin",
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
        value => "${bin_path}/archive_command.sh ${walg_env_file} %p",
        ;
      'restore_command':
        value => "${bin_path}/restore_command.sh ${walg_env_file} %f %p",
        ;
    }
    cron { 'full-backup':
      command => "${bin_path}/cron-full-backup.sh ${walg_env_file} ${retention} | logger -t walg-fullbackup",
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
