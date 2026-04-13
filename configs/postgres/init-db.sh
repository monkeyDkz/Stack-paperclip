#!/bin/bash
set -e

# Create databases for each service
for db in gitea_db paperclip_db; do
  echo "Creating database: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
    CREATE DATABASE $db;
EOSQL
done

echo "All databases created."
