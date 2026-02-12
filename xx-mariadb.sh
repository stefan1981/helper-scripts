#!/bin/bash

# check if .env file exists in the current folder
if [ ! -f ".env" ]; then
    echo "This script can only be executed in a folder that contains a .env file"
    echo "with the values MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD"
    exit 0
fi

source .env

# check if environment variables exist
if [ -z "${MYSQL_DATABASE}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ] || [ -z "${DB_CONTAINER_NAME}" ]; then
    echo "Check that this values exist in .env file: MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD, DB_CONTAINER_NAME"
    exit 0  # Exit with an error code
fi

DBNAME=${MYSQL_DATABASE}
USER=${MYSQL_USER}
PASSWORD=${MYSQL_PASSWORD}
CONTAINER_NAME=${DB_CONTAINER_NAME}

DEXEC="docker exec -i ${CONTAINER_NAME}"
MDB="mariadb -u ${USER} -p${PASSWORD} -D ${DBNAME}"


if [ "$1" == "db-show" ]; then
    echo ${DEXEC} ${MDB} -e "SHOW DATABASES;"
    ${DEXEC} ${MDB} -t -e "
        SELECT
        s.SCHEMA_NAME        AS database_name,
        s.DEFAULT_CHARACTER_SET_NAME AS charset,
        COUNT(t.TABLE_NAME) AS tables,
        ROUND(SUM(IFNULL(t.DATA_LENGTH + t.INDEX_LENGTH, 0)) / 1024 / 1024, 2) AS size_mb
        FROM information_schema.SCHEMATA s
        LEFT JOIN information_schema.TABLES t
        ON s.SCHEMA_NAME = t.TABLE_SCHEMA
        GROUP BY s.SCHEMA_NAME, s.DEFAULT_CHARACTER_SET_NAME
        ORDER BY size_mb DESC;
    "

elif [ "$1" == "drop-db" ]; then
    ${DEXEC} ${MDB} -e "DROP DATABASE $2;"
    echo $2

elif [ "$1" == "tables-show" ]; then
    ${DEXEC} ${MDB} --table -e "
        SELECT
            table_schema                         AS database_name,
            table_name,
            engine,
            table_rows                           AS row_count,
            ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
        FROM information_schema.tables
        WHERE table_schema = '${DBNAME}'
        ORDER BY size_mb DESC;
    "

elif [ "$1" == "table-drop" ]; then
    ${DEXEC} ${MDB} -e "
        DROP TABLE $2;
    "

elif [ "$1" == "table-truncate" ]; then
    ${DEXEC} ${MDB} -e "
        TRUNCATE TABLE $2;
    "


elif [ "$1" == "select-all" ]; then
    ${DEXEC} ${MDB} --table -e "SELECT * FROM $2;"

elif [ "$1" = "select" ]; then
    shift
    SQL="$*"
    ${DEXEC} ${MDB} --batch --table --execute="$SQL" 2>/dev/null


elif [ "$1" == "users-show" ]; then
    ${DEXEC} ${MDB} -e "SELECT User, Host FROM mysql.user;"

elif [ "$1" == "show-grants" ]; then
    ${DEXEC} ${MDB} -e "SHOW GRANTS FOR $2;"
    echo $2

elif [ "$1" == "grant-all-privileges" ]; then
    ${DEXEC} ${MDB} -e "GRANT ALL PRIVILEGES ON $2.* TO '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

elif [ "$1" == "revoke-all-privileges" ]; then
    ${DEXEC} ${MDB} -e "REVOKE ALL PRIVILEGES ON $2.* FROM '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

elif [ "$1" == "dump-database" ]; then
    echo "dump general database into file (my_general.sql)"
    ${DEXEC} mariadb-dump -u root -p${PASSWORD} general > my_general.sql

elif [ "$1" == "restore" ]; then
    echo "restore my_general.sql into database general2 (delete general2 before)"
    ${DEXEC} ${MDB} -e "DROP DATABASE IF EXISTS ${DBNAME}"
    ${DEXEC} ${MDB} -e "CREATE DATABASE IF NOT EXISTS ${DBNAME}"
    cat my_general.sql | ${DEXEC} ${MDB} ${DBNAME}





else
    echo "Usage:"
    echo "✅ xx-mariadb db-show                   # show all dbs"
    echo "$0 db-drop db                           # drop the db with the name db"
    echo "✅ xx-mariadb tables-show               # show all dbs"
    echo "✅ xx-mariadb table-truncate table      # truncate a table"
    echo "✅ xx-mariadb table-drop table          # drop a table"

    echo "✅ xx-mariadb select-all table          # select all records from a table"
    echo "✅ xx-mariadb select query              # select the specific query"

    echo "✅ xx-mariadb users-show                # show all users"
    echo "✅ xx-mariadb show-grants user          # show all grants of a specific user"
    echo "$0 grant-all-privileges db user         # grant all privileges for user on db"
    echo "$0 revoke-all-privileges db user        # revoke all privileges for user on db"
    echo "$0 dump                                 # store db general to my_general.sql file"
    echo "$0 restore                              # restore my_general.sql file to general2 db"
    exit 1
fi
