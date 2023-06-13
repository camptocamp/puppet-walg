# @summary Download wal-g binary
#
# This class download wal-g binary and install it in path
#
# @example
#   include walg::install
class walg::install(
  $install_root = "/opt/wal-g",
  $install_path = "${install_root}/${walg::checksum}" )
  {
  assert_private()
  file { [$install_root,$install_path] :
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }
  -> archive { '/tmp/wal-g.linux-amd64.tar.gz':
    ensure        => present,
    extract       => true,
    extract_path  => $install_path,
    source        => $walg::source,
    checksum      => $walg::checksum,
    checksum_type => 'sha256',
    cleanup       => true,
    creates       => "${install_path}/${walg::binary_name}"
  }
  -> file { "$install_path/${walg::binary_name}":
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }
  -> file { "${walg::destination}/wal-g":
    ensure => link,
    target => "${install_path}/${walg::binary_name}"
  }
}
