#!/bin/bash

# check if .env file exists in the current folder
if [ ! -f ".env" ]; then
    echo "This script can only be executed in a folder that contains a .env file"
    echo "with the values MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD, MYSQL_CONTAINER_NAME"
    exit 0
fi

source .env

# check if environment variables exist
if [ -z "${MYSQL_DATABASE}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ] || [ -z "${MYSQL_CONTAINER_NAME}" ]; then
    echo "Check that this values exist in .env file: MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD, MYSQL_CONTAINER_NAME"
    exit 0  # Exit with an error code
fi

DBNAME=${MYSQL_DATABASE}
USER=${MYSQL_USER}
PASSWORD=${MYSQL_PASSWORD}
CONTAINER_NAME=${MYSQL_CONTAINER_NAME}

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

elif [ "$1" == "db-dump" ]; then
    echo "dump $DBNAME database into file ($2)"
    ${DEXEC} mariadb-dump -u root -p${PASSWORD} $DBNAME > $2


elif [[ "$1" == "tables-show" || "$1" == "t" ]]; then
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

elif [ "$1" == "table-dump" ]; then
    TABLE=$2
    FILENAME="${3:-${TABLE}.sql}"
    echo "dump table $TABLE from $DBNAME into file ($FILENAME)"
    ${DEXEC} mariadb-dump -u root -p${PASSWORD} $DBNAME $TABLE > "$FILENAME"

elif [ "$1" == "table-restore" ]; then
    TABLE=$2
    FILENAME=$3
    echo "restore table $TABLE from $FILENAME into $DBNAME"
    cat "$FILENAME" | ${DEXEC} mariadb -u root -p${PASSWORD} "$DBNAME"


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


elif [[ "$1" == "help" || "$1" == "h" ]]; then
    script=$(basename "$0")
    echo "$0 - The mariadb helper script!"
    echo "---------------------------------------------------------------------------------------------------"
    echo "Usage:"
    echo "$script parameter"
    echo ""
    echo "Parameters:"
    echo "db-show                              show all databases"
    echo "db-drop db                           drop the db with the name db"
    echo "db-dump filename                     dump current database to filename"
    echo ""
    echo "tables-show                          (t) show all tables"
    echo "table-drop table                     drop a table"
    echo "table-truncate table                 truncate a table"
    echo "table-dump table [filename]          dump a single table to file (default: table.sql)"
    echo "table-restore table filename         restore a single table from file into current database"
    echo ""
    echo "select-all table                     select all records from a table"
    echo "select query                         select the specific query"
    echo "users-show                           show all users"
    echo "show-grants user                     show all grants of a specific user"
    echo "grant-all-privileges db user         grant all privileges for user on db"
    echo "revoke-all-privileges db user        revoke all privileges for user on db"
    echo "help                                 (h) show this help"
    echo ""

else
    exit 1
fi
