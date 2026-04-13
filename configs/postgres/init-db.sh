#!/bin/bash
set -e

echo "=== Création des bases de données ==="

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL

    CREATE DATABASE gitea_db;
    CREATE DATABASE n8n_db;
    CREATE DATABASE twenty_db;
    CREATE DATABASE paperclip_db;

EOSQL

echo "=== Bases créées : gitea_db, n8n_db, twenty_db, paperclip_db ==="
