#!/bin/bash

# check if .env file exists in the current folder
if [ ! -f ".env" ]; then
    echo "This script can only be executed in a folder that contains a .env file"
    echo "with the values POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD"
    exit 0
fi

source .env

# check if environment variables exist
if [ -z "${POSTGRES_DATABASE}" ] || [ -z "${POSTGRES_USER}" ] || [ -z "${POSTGRES_PASSWORD}" ]; then
    echo "Check that this values exist in .env file: POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD"
    exit 0  # Exit with an error code
fi

DBNAME=${POSTGRES_DATABASE}
USER=${POSTGRES_USER}
PASSWORD=${POSTGRES_PASSWORD}

DEXEC="docker exec -i datastore-postgres"
MDB="psql -U ${USER} -d ${DBNAME} -c"
MDB2="psql -U ${USER} -d ${DBNAME} -t -A -X -q -c"

if [ "$1" == "check-connection" ]; then
    ${DEXEC} pg_isready -U ${USER} -d ${DBNAME}

elif [ "$1" == "db-show" ]; then
    ${DEXEC} ${MDB} "\l"

elif [ "$1" == "tables-show" ]; then
    ${DEXEC} ${MDB} "\dt"

elif [ "$1" == "table-create" ]; then
    ${DEXEC} ${MDB} "
    CREATE TABLE $2 (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"

elif [ "$1" == "table-drop" ]; then
    ${DEXEC} ${MDB} "
    DROP TABLE IF EXISTS $2"

elif [ "$1" == "select" ]; then
    ${DEXEC} ${MDB} "
    SELECT * FROM $2"

elif [ "$1" == "dump-table" ]; then
    ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -t $2 > $3

elif [ "$1" == "extension-create-vector" ]; then
    ${DEXEC} ${MDB} "
    CREATE EXTENSION IF NOT EXISTS vector"

elif [ "$1" == "extensions-show" ]; then
    ${DEXEC} ${MDB} "
    SELECT * FROM pg_extension"

elif [ "$1" == "leika-str" ]; then
    ${DEXEC} ${MDB2} "
    SELECT json_agg(t)
    FROM (
        SELECT * FROM leika_codes where description like '%$2%'
    ) t"

elif [ "$1" == "leika-nr" ]; then
    ${DEXEC} ${MDB2} "
    SELECT json_agg(t)
    FROM (
        SELECT * FROM leika_codes where leika_code like '%$2%'
    ) t"

elif [ "$1" == "leika-detail" ]; then
    ${DEXEC} ${MDB} "
    SELECT leika_code, description FROM leika_codes where leika_code like '$2%'"

elif [ "$1" == "leika-typedist" ]; then
    ${DEXEC} ${MDB} "
    SELECT type, count(type) AS anz FROM leika_codes GROUP BY type ORDER by anz DESC"

elif [ "$1" == "leika-sdg" ]; then
    ${DEXEC} ${MDB2} "
    SELECT json_agg(t)
    FROM (
        SELECT * FROM leika_codes where sdg_info_area like '%$2%'
    ) t"

elif [ "$1" == "leika-sdg-dist" ]; then
    ${DEXEC} ${MDB2} "
    SELECT json_agg(t)
    FROM (
        SELECT sdg_info_area, count(sdg_info_area) AS cnt
        FROM leika_codes GROUP BY sdg_info_area ORDER by cnt DESC
    ) t"
else
    echo "Usage:"
    echo "$0 check-connection              # check connection"
    echo "$0 db-show                       # show all databases"
    echo "$0 tables-show                   # show all tables"
    echo "$0 table-create name             # create a table with name"
    echo "$0 table-drop name               # drop (delete) the table name"
    echo "$0 select name                   # select some data from name"
    echo "$0 dump-table table file         # dump table to file"
    echo "$0 extension-create-vector       # create vector extension"
    echo "$0 extensions-show               # show installed extensions"
    echo "$0 leika-str str                 # search for leika description"
    echo "$0 leika-nr str                  # search for leika code"
    echo "$0 leika-detail str              # search for leika details"
    echo "$0 leika-typedist                # search for leika type distribution"
    echo "$0 leika-sdg str                 # search for sdg info"
    echo "$0 leika-sdg-dist                # search for sdg distribution"
    exit 1
fi
