#!/bin/bash

source /usr/local/bin/exporter.env
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export WALE_S3_PREFIX
export AWS_ENDPOINT
export AWS_S3_FORCE_PATH_STYLE
export AWS_REGION
export WALG_PGP_KEY_PATH
export WALG_GPG_KEY_ID
export WALG_PGP_KEY_PASSPHRASE
export S3_USE_LIST_OBJECTS_V1

exec /usr/local/bin/wal-g $*
