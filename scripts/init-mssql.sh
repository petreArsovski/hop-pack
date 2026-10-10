#!/usr/bin/env bash
# SQL Server does not auto-run /docker-entrypoint-initdb.d. Apply T-SQL seeds with sqlcmd.
set -euo pipefail

SA_PASSWORD="${MSSQL_SA_PASSWORD:-HopBarrel1!}"
HOST="${MSSQL_HOST:-mssql}"
SQL_DIR="${SQL_DIR:-/docker-entrypoint-initdb.d}"

sqlcmd_bin=""
for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd sqlcmd; do
  if [[ -x "${candidate}" ]] || command -v "${candidate}" >/dev/null 2>&1; then
    sqlcmd_bin="${candidate}"
    break
  fi
done

if [[ -z "${sqlcmd_bin}" ]]; then
  echo "sqlcmd not found in this image" >&2
  exit 1
fi

echo "Seeding SQL Server at ${HOST} from ${SQL_DIR}"
shopt -s nullglob
files=("${SQL_DIR}"/*.sql)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .sql files in ${SQL_DIR}" >&2
  exit 1
fi

for f in "${files[@]}"; do
  echo "Applying ${f}"
  "${sqlcmd_bin}" -S "${HOST}" -U sa -P "${SA_PASSWORD}" -C -b -l 30 -i "${f}"
done

echo "MSSQL seed complete"
