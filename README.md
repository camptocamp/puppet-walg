# Puppet Wal-g module

Setup PostgreSQL backup with [wal-g](https://github.com/wal-g/wal-g).

## Description

This module configures continuous WAL archiving and full backups via wal-g:

- Downloads and installs the `wal-g` binary
- Sets up `archive_command` and `restore_command` for PostgreSQL
- Creates scripts for WAL push, restore, and full backup
- Installs a cron job for periodic full backups with retention
- Optionally deploys a [wal-g prometheus exporter](https://github.com/camptocamp/wal-g-prometheus-exporter)
- Optionally enables a disk-pressure circuit breaker that pauses archiving when disk is nearly full

## Usage

### Basic setup

```puppet
class { 'walg':
  source         => 'https://github.com/wal-g/wal-g/releases/download/v3.0.1/wal-g-pg-ubuntu-22.04-amd64.tar.gz',
  checksum       => 'abc123...',
  binary_name    => 'wal-g-pg-ubuntu-22.04-amd64',
}
```

### With disk pressure protection

```puppet
class { 'walg':
  source                                      => 'https://github.com/wal-g/wal-g/releases/download/v3.0.1/wal-g-pg-ubuntu-22.04-amd64.tar.gz',
  checksum                                    => 'abc123...',
  binary_name                                 => 'wal-g-pg-ubuntu-22.04-amd64',
  pause_archive_on_disk_pressure              => true,
  pause_archive_on_disk_pressure_threshold_gbytes => 10240,
}
```

When the disk is nearly full (free space drops below the threshold), the archive
command exits successfully without pushing WAL to S3. PostgreSQL treats the WAL
as **archived** and recycles it from `pg_wal/`.

**This creates a gap in your backup chain.** Any WAL generated while the alert
file exists is permanently lost — PITR to a point inside that window won't be
possible.

This is an intentional trade-off: losing a few WALs is preferred over PostgreSQL
crashing when `pg_wal/` fills the entire disk. Once space frees up, archiving
resumes automatically, but the gap remains.

### Without monitoring

```puppet
class { 'walg':
  source     => 'https://github.com/wal-g/wal-g/releases/download/v3.0.1/wal-g-pg-ubuntu-22.04-amd64.tar.gz',
  checksum   => 'abc123...',
  binary_name => 'wal-g-pg-ubuntu-22.04-amd64',
  monitoring => false,
}
```

## Reference

### `walg`

The main entry point class.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source` | `Stdlib::HTTPSUrl` | — | URL to download the wal-g archive |
| `checksum` | `String[1]` | — | SHA256 checksum of the archive |
| `binary_name` | `String[1]` | — | Name of the binary inside the archive |
| `destination` | `Stdlib::Absolutepath` | `/usr/local/bin` | Directory for the `wal-g` symlink |
| `walg_env_file` | `Stdlib::Absolutepath` | `/etc/walg.env` | File name saved walg environment variables |
| `retention` | `Integer` | `15` | Days of full backups to keep |
| `cron_hour` | `Integer` | `2` | Hour for the full backup cron job |
| `cron_minute` | `Integer` | `20` | Minute for the full backup cron job |
| `backup_enable` | `Boolean` | `true` | Enable WAL archiving and full backups |
| `pause_archive_on_disk_pressure` | `Boolean` | `false` | Enable circuit breaker that pauses archiving when disk is nearly full |
| `pause_archive_on_disk_pressure_threshold_gbytes` | `Optional[Integer]` | `undef` | Free space threshold in GB (required when `pause_archive_on_disk_pressure` is `true`) |
| `monitoring` | `Boolean` | `true` | Deploy the wal-g prometheus exporter |
| `prometheus_labels` | `Hash` | `{}` | Extra labels for the prometheus scrape job |

### `walg::install`

Downloads and extracts the wal-g archive.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `install_root` | `String` | `/opt/wal-g` | Root directory for extracted binaries |
| `install_path` | `String` | `${install_root}/${checksum}` | Versioned subdirectory (keyed by checksum for upgrade safety) |
| `package_path` | `String` | `/tmp/wal-g-${binary_name}.tar.gz` | Temporary path for the downloaded archive |
| `destination` | `String` | `$walg::destination` | Symlink target directory for `wal-g` |

### `walg::config`

Deploys shell scripts, PostgreSQL config entries, and cron jobs.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `retention` | `Integer` | `$walg::retention` | Days of full backups to keep |
| `cron_hour` | `Integer` | `$walg::cron_hour` | Hour for the full backup cron job |
| `cron_minute` | `Integer` | `$walg::cron_minute` | Minute for the full backup cron job |
| `backup_enable` | `Boolean` | `$walg::backup_enable` | Enable WAL archiving and full backups |
| `pause_archive_on_disk_pressure` | `Boolean` | `$walg::pause_archive_on_disk_pressure` | Enable disk-pressure circuit breaker |
| `pause_archive_on_disk_pressure_threshold_gbytes` | `Optional[Integer]` | `$walg::pause_archive_on_disk_pressure_threshold_gbytes` | Free space threshold in GB |
| `pause_archive_on_disk_pressure_alert_file` | `Stdlib::Absolutepath` | `/tmp/failed_pg_archive` | Sentry file created when archiving is paused |
| `bin_path` | `Stdlib::Absolutepath` | `$walg::destination` | Directory for deployed scripts |
| `walg_env_file` | `Stdlib::Absolutepath` | `$walg::walg_env_file` | File name saved walg environment variables |

This class manages the following scripts in `${bin_path}`:

- `archive_command.sh` — invoked by PostgreSQL for each WAL segment; calls `wal-g wal-push`
- `restore_command.sh` — invoked by PostgreSQL during recovery; calls `wal-g wal-fetch`
- `wal-g.sh` — generic wrapper sourcing `exporter.env` then running `wal-g`
- `cron-full-backup.sh` — runs `wal-g backup-push`, then prunes old backups
- `pause-archive-on-disk-pressure.sh` — (optional) created when `pause_archive_on_disk_pressure` is enabled; checks disk usage and creates/removes the alert file

And two root-only scripts:

- `backup-restoration.sh` — interactive manual restore from a basebackup
- `setup-replica-from-backup.sh` — semi-interactive replica provisioning

### `walg::walg_exporter`

Downloads and runs the prometheus exporter for wal-g metrics.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source` | `Stdlib::HttpsUrl` | — | URL for the exporter binary |
| `checksum` | `String[1]` | — | SHA256 checksum of the exporter binary |
| `install_root` | `String` | `/opt/walg_exporter` | Installation directory |
| `scrape_port` | `Integer` | `9351` | Prometheus metrics port |
| `scrape_host` | `String` | `$trusted['certname']` | Hostname for the scrape target |
| `prometheus_labels` | `Hash` | `$walg::prometheus_labels` | Extra prometheus labels |
| `walg_env_file` | `Stdlib::Absolutepath` | `$walg::walg_env_file` | File name saved walg environment variables |

## Environment variables

Credentials and S3 settings are read from  `${walg_env_file}`. Expected variables:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `WALE_S3_PREFIX` (e.g. `s3://bucket/path`)
- `AWS_ENDPOINT`
- `AWS_S3_FORCE_PATH_STYLE`
- `AWS_REGION`
- `WALG_PGP_KEY_PATH`
- `WALG_GPG_KEY_ID`
- `WALG_PGP_KEY_PASSPHRASE`
- `S3_USE_LIST_OBJECTS_V1`

## Limitations

- Requires the `puppetlabs/postgresql` module (for `postgresql::params` and `postgresql::server::config_entry`)
- Requires the `puppet/archive` module (for archive download/extraction)
- Requires the `puppet/systemd` module (for the exporter systemd unit)
- Tested on RedHat 8/9
