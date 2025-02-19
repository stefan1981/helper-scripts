#!/bin/bash

# check if .env file exists in the current folder
if [ ! -f ".env" ]; then
    echo "This script can only be executed in a folder that contains a .env file"
    echo "with the values MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD"
    exit 0
fi

source .env

# check if environment variables exist
if [ -z "${MYSQL_DATABASE}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ]; then
    echo "Check that this values exist in .env file: MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD"
    exit 0  # Exit with an error code
fi

DBNAME=${DB_NAME}
PASSWORD=${MYSQL_PASSWORD}

DEXEC="docker exec -i datastore-mariadb"
MDB="mariadb -u root -p${PASSWORD}"


if [ "$1" == "dump" ]; then
    echo "dump general database into file (my_general.sql)"
    ${DEXEC} mariadb-dump -u root -p${PASSWORD} general > my_general.sql

elif [ "$1" == "restore" ]; then
    echo "restore my_general.sql into database general2 (delete general2 before)"
    ${DEXEC} ${MDB} -e "DROP DATABASE IF EXISTS ${DBNAME}"
    ${DEXEC} ${MDB} -e "CREATE DATABASE IF NOT EXISTS ${DBNAME}"
    cat my_general.sql | ${DEXEC} ${MDB} ${DBNAME}

elif [ "$1" == "db-show" ]; then
    ${DEXEC} ${MDB} -e "SHOW DATABASES;"

elif [ "$1" == "show-users" ]; then
    ${DEXEC} ${MDB} -e "SELECT User, Host FROM mysql.user;"

elif [ "$1" == "drop-db" ]; then
    ${DEXEC} ${MDB} -e "DROP DATABASE $2;"
    echo $2

elif [ "$1" == "show-grants" ]; then
    ${DEXEC} ${MDB} -e "SHOW GRANTS FOR $2;"
    echo $2

elif [ "$1" == "grant-all-privileges" ]; then
    ${DEXEC} ${MDB} -e "GRANT ALL PRIVILEGES ON $2.* TO '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

elif [ "$1" == "revoke-all-privileges" ]; then
    ${DEXEC} ${MDB} -e "REVOKE ALL PRIVILEGES ON $2.* FROM '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

else
    echo "Usage:"
    echo "$0 dump                          # store db general to my_general.sql file"
    echo "$0 restore                       # restore my_general.sql file to general2 db"
    echo "$0 db-show                       # show all dbs"
    echo "$0 db-drop db                    # drop the db with the name db"
    echo "$0 users-show                    # show all users"
    echo "$0 show-grants user              # show all grants of a specific user"
    echo "$0 grant-all-privileges db user  # grant all privileges for user on db"
    echo "$0 revoke-all-privileges db user # revoke all privileges for user on db"
    exit 1
fi
