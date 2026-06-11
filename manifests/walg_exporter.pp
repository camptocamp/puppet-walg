# @summary Download and setup a prometheus exporter for backup metrics
#
# This class download a prometheus exporter for wal-g as binary
# and setup a systemd unit to run this exporter
#
# @param source URL to download walg exporter 
# @param checksum Checksum of the walg exporter package
# @param install_root The path to install walg exporter
# @param scrape_host What is the URL that should be used to scrap the node_exporter metric ?
# @param scrape_port Which port should be used for scrapping the metric ?
# @param prometheus_labels Labels to put on metrics reported by exporters
# @param walg_env_file The walg environment variables file path
class walg::walg_exporter (
  Stdlib::HttpsUrl     $source,
  String[1]            $checksum,
  String               $install_root      = '/opt/walg_exporter',
  Integer              $scrape_port       = 9351,
  String               $scrape_host       = $trusted['certname'],
  Hash                 $prometheus_labels = $walg::prometheus_labels,
  Stdlib::Absolutepath $walg_env_file     = $walg::walg_env_file,
) {
  archive { "${install_root}/wal-g-prometheus-exporter":
    ensure        => present,
    source        => $source,
    checksum      => $checksum,
    checksum_type => 'sha256',
    cleanup       => false,
    creates       => "${install_root}/wal-g-prometheus-exporter",
  }

  file { "${install_root}/wal-g-prometheus-exporter":
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => Archive["${install_root}/wal-g-prometheus-exporter"],
  }

  systemd::unit_file { 'wal-g-prometheus-exporter.service':
    content   => epp('walg/wal-g-prometheus-exporter.service',
      {
        'datadir'        => $postgresql::params::datadir,
        'install_root'   => $install_root,
        'walg_env_file'  => $walg_env_file,
      }
    ),
    enable    => true,
    active    => true,
    subscribe => File["${install_root}/wal-g-prometheus-exporter"],
  }

  $default_labels = {
    'job' => 'walg_exporter',
  }

  @@prometheus::scrape_job { "${scrape_host}:${scrape_port}":
    job_name => 'walg_exporter',
    targets  => ["${scrape_host}:${scrape_port}"],
    labels   => $default_labels + $prometheus_labels,
  }
}
