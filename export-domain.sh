#!/bin/bash

# This script will export a tar file from incremental backups for the specified date and domain.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \nexport-domain.sh domain.com 2021-10-15 \n-- NOTE: you can specify either a website domain or a child domain that belongs to a website"

# Assign arguments
DOMAIN=$1
DATE=$2

# Checking required arguments
if [[ "$#" -lt 2 ]]; then
    echo "-- ERROR: arguments are missing..."
    echo -e "$USAGE"
    exit 1
fi

# Checking date format (YYYY-MM-DD)
if [[ ! $DATE =~ ^20[0-9]{2}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
    echo "-- ERROR: the date format is not correct"
    echo -e "$USAGE"
    exit 2
fi

# Set script start time to calculate duration
START_TIME=$(date +%s)

# Adding the domains dir to export dir
EXPORT_DIR="$EXPORT_DIR/domains"

DOMAIN_REPO=$REPO_DOMAINS_DIR/$DOMAIN
EXPORT_LOCATION="local"

# Check if domain repo exist
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$DOMAIN_REPO/data"; then
    echo "-- ERROR: There is no backup for domain $DOMAIN."
    exit 3
fi

# This should happen after checking if the dir exists because the dir-exists needs the pure path to directory and not the ssh one
if [[ -n $SSH_HOST ]]; then
    DOMAIN_REPO="$SSH_DESTINATION/${DOMAIN_REPO#/}"
    EXPORT_LOCATION="remote ssh"
fi

# Check if backup archive date exist for the given domain
if ! borg list "$DOMAIN_REPO" | grep -q "$DATE"; then
    echo "-- ERROR: There is no backup for domain $DOMAIN for date $DATE."
    echo "-- The following backups are available for this domain"
    borg list "$DOMAIN_REPO"
    exit 4
fi

read -p "Are you sure you want to export tar for domain $DOMAIN for date $DATE to $EXPORT_LOCATION location $EXPORT_DIR? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    # This is to avoid exiting the script if the script is sourced
    [[ "$0" = "$BASH_SOURCE" ]]
    echo
    echo "---------- EXPORT CANCELED! -----------"
    exit 6
fi

echo
echo "---------- EXPORT STARTED! -----------"

# Create export dir if it doesn't exist
"$CURRENT_DIR"/helpers/mkdir-if-not-exist.sh "$EXPORT_DIR"

# Pipe the tar file to the destination
if [[ -z $SSH_HOST ]]; then
    # local export
    borg export-tar --tar-filter="gzip -9" "$DOMAIN_REPO"::"$DATE" "$EXPORT_DIR/${DOMAIN}_$DATE.tar.gz"
else
    # remote export
    # We have to export to a temp file because borg export-tar doesn't support piping to a remote location
    TMP_FILE=/tmp/"${DOMAIN}_$DATE.tar.gz"

    echo "-- Creating tar.gz file from backup"
    borg export-tar --tar-filter="gzip -9" "$DOMAIN_REPO"::"$DATE" "$TMP_FILE"

    echo "-- Uploading $TMP_FILE to $EXPORT_DIR"
    # We have to remove the leading / in front of the export dir. Otherwise we get an error "No such file or directory"
    scp -P "$SSH_PORT" "$TMP_FILE" "$SSH_USER"@"$SSH_HOST":"${EXPORT_DIR#/}/"

    echo "-- Removing temp file $TMP_FILE"
    rm "$TMP_FILE"
fi

echo "---------- EXPORT COMPLETED! -----------"
echo "-- Exported file: $EXPORT_DIR/${DOMAIN}_$DATE.tar.gz"

END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))

echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
