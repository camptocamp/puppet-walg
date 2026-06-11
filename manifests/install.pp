# @summary Download wal-g binary
#
# This class download wal-g binary and install it in path
#
# @param install_root The installation root path
# @param install_path The installation path contains package checksum
# @param package_path The path to download the archive
# @param source URL to download walg binary
# @param checksum Checksum of the walg package
# @param binary_name The binary name of walg
# @param destination The walg binary symlink destination path
class walg::install (
  String $install_root = '/opt/wal-g',
  String $install_path = "${install_root}/${walg::checksum}",
  String $package_path = "/tmp/wal-g-${walg::binary_name}.tar.gz",
  String $source       = $walg::source,
  String $checksum     = $walg::checksum,
  String $binary_name  = $walg::binary_name,
  String $destination  = $walg::destination,
) {
  assert_private()
  file { [$install_root,$install_path]:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  archive { $package_path:
    ensure        => present,
    extract       => true,
    extract_path  => $install_path,
    source        => $source,
    checksum      => $checksum,
    checksum_type => 'sha256',
    cleanup       => true,
    creates       => "${install_path}/${binary_name}",
  }

  file { "${install_path}/${binary_name}":
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => Archive[$package_path],
  }

  file { "${destination}/wal-g":
    ensure  => link,
    target  => "${install_path}/${binary_name}",
    require => File["${install_path}/${binary_name}"],
  }
}
