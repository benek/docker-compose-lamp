#!/usr/bin/env bash
# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Determine the script's root directory and navigate to it
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"

# Create timestamped backup directory if not exists
timestamp="$(date +%Y%m%d-%H%M)"
backup_dir="backups/${timestamp}"
mkdir -p "$backup_dir"

# Load environment variables from .env file if it exists
if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . ".env"
  set +a
fi

# Extract database credentials from environment variables
db_name="${MYSQL_DATABASE:-}"
db_root_password="${MYSQL_ROOT_PASSWORD:-}"

# Validate that required database credentials are present
if [[ -z "$db_name" || -z "$db_root_password" ]]; then
  echo "Missing MYSQL_DATABASE or MYSQL_ROOT_PASSWORD. Set them in .env or env vars." >&2
  exit 1
fi

# Dump the MySQL database to a SQL file
docker compose exec -T database mysqldump -u root -p"${db_root_password}" "${db_name}" > "${backup_dir}/db.sql"

# Archive site files, excluding MySQL data and cached CSS/JS files
tar -czf "${backup_dir}/site.tgz" \
  --exclude='data/mysql' \
  --exclude='data/mysql/*' \
  --exclude='www/legacy/sites/default/files/css/*' \
  --exclude='www/legacy/sites/default/files/js/*' \
  www config .env data

# Save the resolved Docker Compose configuration
docker compose config > "${backup_dir}/compose.resolved.yml"

# Display backup completion message
echo "Backup created at ${backup_dir}"
