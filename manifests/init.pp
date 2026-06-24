# @summary Download and setup wal-g
#
# Download and setup wal-g for backup
#
# @param source URL to download walg binary
# @param checksum Checksum of the walg package
# @param binary_name The binary name of walg
# @param destination The walg binary symlink destination path
# @param retention How many days of postgresql backup will be kept
# @param cron_hour The backup cronjob hour
# @param cron_minute The backup cronjob minute
# @param backup_enable If enable Postgresql wal continues backup and fullbackup
# @param pause_archive_on_disk_pressure Check if the disk is almost full due to accumulating wals
# @param pause_archive_on_disk_pressure_threshold_gbytes The threshold to trigger archive pause
# @param monitoring If install walg-exporter and declare a prometheus probe, default to true
# @param prometheus_labels Labels to put on metrics reported by exporters
# @param walg_env_file The walg environment variables file path
class walg (
  Stdlib::HTTPSUrl     $source,
  String[1]            $checksum,
  String[1]            $binary_name,
  Optional[Integer]    $pause_archive_on_disk_pressure_threshold_gbytes = undef,
  Stdlib::Absolutepath $destination                                     = '/usr/local/bin',
  Stdlib::Absolutepath $walg_env_file                                   = '/etc/walg.env',
  Integer              $retention                                       = 15,
  Integer              $cron_hour                                       = 2,
  Integer              $cron_minute                                     = 20,
  Boolean              $backup_enable                                   = true,
  Boolean              $pause_archive_on_disk_pressure                  = false,
  Boolean              $monitoring                                      = true,
  Hash                 $prometheus_labels                               = {},
) {
  if $pause_archive_on_disk_pressure and ( $pause_archive_on_disk_pressure_threshold_gbytes == undef ) {
    fail('pause_archive_on_disk_pressure_threshold_gbytes must be set when pause_archive_on_disk_pressure is true')
  }

  include walg::install
  include walg::config

  if $monitoring {
    include  walg::walg_exporter
  }
}
