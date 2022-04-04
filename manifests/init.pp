# @summary Download and setup wal-g
#
# Download and setup wal-g for backup
#
# @example
#   include walg
class walg (
  Stdlib::HTTPSUrl     $source,
  String[1]            $checksum,
  Integer              $retention,
  Integer              $cron_hour,
  Integer              $cron_minute,
  Stdlib::Absolutepath $destination = '/usr/local/bin',
  Boolean              $prometheus_exporter = true,
  Boolean              $backup_enable = true,
  Boolean              $backup_fuse = false,
  Integer              $backup_fuse_threshold_gbytes = 10,
  String               $backup_prefix = '',
) {
  class { 'walg::install': }
  -> class { 'walg::config': }

  if $prometheus_exporter {
    class { 'walg::prometheus_exporter': }
    contain walg::prometheus_exporter
  }

  contain walg::install, walg::config
}
