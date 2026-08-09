#!/usr/bin/env sh
# Back up a running Local Drive. The database copy uses VACUUM INTO, which is
# safe to run while the server is serving traffic, and the library is rsynced
# alongside it.
#
# Usage:
#   scripts/backup.sh /path/to/backups
#
# As a nightly cron entry:
#   15 3 * * * /srv/localdrive/scripts/backup.sh /mnt/backup/localdrive >> /var/log/localdrive-backup.log 2>&1

set -eu

DEST="${1:-}"
if [ -z "$DEST" ]; then
	echo "usage: $0 <destination directory>" >&2
	exit 1
fi

DATA_DIR="${DATA_DIR:-./data}"
DB_PATH="${DB_PATH_HOST:-$DATA_DIR/db/localdrive.sqlite}"
LIBRARY_PATH="${LIBRARY_PATH_HOST:-$DATA_DIR/library}"
KEEP_DAYS="${KEEP_DAYS:-14}"

STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="$DEST/$STAMP"

mkdir -p "$TARGET"

echo "backing up the database"
if command -v sqlite3 >/dev/null 2>&1; then
	sqlite3 "$DB_PATH" "VACUUM INTO '$TARGET/localdrive.sqlite'"
else
	# no sqlite3 on the host, borrow the one inside the container
	docker compose exec -T server sh -c \
		"sqlite3 \"\$DB_PATH\" \"VACUUM INTO '/tmp/backup.sqlite'\"" 2>/dev/null ||
		{
			echo "sqlite3 is not available on the host or in the container." >&2
			echo "install sqlite3, or stop the server and copy $DB_PATH by hand." >&2
			exit 1
		}
	docker compose cp server:/tmp/backup.sqlite "$TARGET/localdrive.sqlite"
	docker compose exec -T server rm -f /tmp/backup.sqlite
fi

echo "backing up the library"
rsync -a --delete "$LIBRARY_PATH/" "$TARGET/library/"

echo "recording what this backup came from"
{
	echo "created_at=$(date -Iseconds)"
	echo "db_path=$DB_PATH"
	echo "library_path=$LIBRARY_PATH"
	echo "host=$(hostname)"
} > "$TARGET/backup.info"

if [ "$KEEP_DAYS" -gt 0 ]; then
	echo "removing backups older than $KEEP_DAYS days"
	find "$DEST" -mindepth 1 -maxdepth 1 -type d -mtime "+$KEEP_DAYS" -exec rm -rf {} +
fi

echo "done: $TARGET"
echo
echo "To restore: stop the server, put localdrive.sqlite back at $DB_PATH,"
echo "put library/ back at $LIBRARY_PATH, then start the server again."
