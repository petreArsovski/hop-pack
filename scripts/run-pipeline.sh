#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d --wait mssql mssql-init postgres
docker compose --profile run build pipeline
docker compose --profile run run --rm pipeline
