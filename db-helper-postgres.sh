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

if [ "$1" == "db-show" ]; then
    ${DEXEC} ${MDB} "\l"

elif [ "$1" == "tables-show" ]; then
    ${DEXEC} ${MDB} "\dt"

elif [ "$1" == "table-create" ]; then
    ${DEXEC} ${MDB} "
    CREATE TABLE example (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"

else
    echo "Usage:"
    echo "$0 db-show                       # show all databases"
    echo "$0 tables-show                   # show all tables"
    echo "$0 table-create                  # create a table"
    exit 1
fi
