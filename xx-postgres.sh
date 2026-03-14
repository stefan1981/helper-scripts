#!/bin/bash

# check if .env file exists in the current folder
if [ ! -f ".env" ]; then
    echo "This script can only be executed in a folder that contains a .env file"
    echo "with the values POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_CONTAINER_NAME"
    exit 0
fi

source .env

# check if environment variables exist
if [ -z "${POSTGRES_DATABASE}" ] || [ -z "${POSTGRES_USER}" ] || [ -z "${POSTGRES_PASSWORD}" ] || [ -z "${POSTGRES_CONTAINER_NAME}" ]; then
    echo "Check that this values exist in .env file: POSTGRES_DATABASE, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_CONTAINER_NAME"
    exit 0  # Exit with an error code
fi

DBNAME=${POSTGRES_DATABASE}
USER=${POSTGRES_USER}
PASSWORD=${POSTGRES_PASSWORD}
CONTAINER_NAME=${POSTGRES_CONTAINER_NAME}

DEXEC="docker exec -i ${CONTAINER_NAME}"
MDB="psql -U ${USER} -d ${DBNAME} -c"
MDB2="psql -U ${USER} -d ${DBNAME} -t -A -X -q -c"



if [ "$1" == "check-connection" ]; then
    echo "..."
    ${DEXEC} pg_isready -U ${USER} -d ${DBNAME}

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-show" ]; then
    ${DEXEC} psql -U ${USER} -d postgres -c "\l"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-store" ]; then
    ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -C > $2
    echo "Database dumped to $2"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-restore" ]; then
    cat $2 | ${DEXEC} psql -U ${USER} -d postgres
    echo "Database restored from $2"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-drop" ]; then
    ${DEXEC} psql -U ${USER} -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${DBNAME}' AND pid <> pg_backend_pid();"
    ${DEXEC} psql -U ${USER} -d postgres -c "DROP DATABASE ${DBNAME};"
    echo "Database ${DBNAME} dropped"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-create" ]; then
    ${DEXEC} psql -U ${USER} -d postgres -c "CREATE DATABASE ${DBNAME};"
    echo "Database ${DBNAME} created"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "tables-show" || "$1" == "t" ]]; then
    ${DEXEC} ${MDB} "
        SELECT
            schemaname AS schema,
            relname   AS table_name,
            n_live_tup AS rows,
            n_dead_tup AS dead_rows,
            pg_size_pretty(pg_total_relation_size(relid)) AS size,
            last_autovacuum::timestamp(0) AS last_autovacuum,
            last_autoanalyze::timestamp(0) AS last_autoanalyze
        FROM pg_stat_user_tables
        ORDER BY n_live_tup DESC;";    

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "table-count" || "$1" == "c" ]]; then
    ${DEXEC} ${MDB} "
    SELECT count(*) FROM \"$2\""

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-create" ]; then
    ${DEXEC} ${MDB} "
    CREATE TABLE $2 (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"
# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-create-vector" ]; then
    ${DEXEC} ${MDB} "
    CREATE TABLE $2 (
        id SERIAL PRIMARY KEY,
        name TEXT,
        embedding VECTOR(3) -- Change 3 to the actual dimension of your vectors
    );"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-show-columns" ]; then
    ${DEXEC} ${MDB} "
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name   = '$2'"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-store" ]; then
    ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -t "\"$2\"" > $3

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-restore" ]; then
    # $2 = path to .sql file
    cat $2 | ${DEXEC} psql -U ${USER} -d ${DBNAME}

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "tables-store" ]; then
    json=$(${DEXEC} ${MDB2} "
    SELECT json_agg(t)
    FROM (
        SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    ) t")
    # Loop through each tablename and append ".sql"
    for tablename in $(echo "$json" | jq -r '.[].tablename'); do
        sql_file="${tablename}.sql"
        echo "$sql_file"
        mkdir -p $2
        ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -t "\"${tablename}\"" > "$2/$sql_file"
    done

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "tables-restore" ]; then
    # $2 = folder path containing .sql files
    for sql_file in "$2"/*.sql; do
        if [ -f "$sql_file" ]; then
            echo "Restoring $(basename "$sql_file")..."
            cat "$sql_file" | ${DEXEC} psql -U ${USER} -d ${DBNAME}
        fi
    done
    echo "All tables restored from $2"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-drop" ]; then
    ${DEXEC} ${MDB} "
    DROP TABLE IF EXISTS \"$2\""

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "tables-drop-all" ]; then
    ${DEXEC} ${MDB} "
    DO \$\$ DECLARE
        r RECORD;
    BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
        LOOP
            EXECUTE 'DROP TABLE IF EXISTS \"' || r.tablename || '\" CASCADE';
        END LOOP;
    END \$\$;"
    echo "All tables dropped"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-truncate" ]; then
    ${DEXEC} ${MDB} "
    TRUNCATE TABLE \"$2\""

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "select" || "$1" == "s" ]]; then
    ${DEXEC} ${MDB} "
    SELECT * FROM \"$2\""

# new generic exec
elif [[ "$1" == "exec" || "$1" == "e" ]]; then
    # everything after $1 is the SQL statement
    shift
    SQL="$*"
    ${DEXEC} ${MDB} "$SQL"




# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "dump-table-inserts" ]; then
    ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -t $2 --column-inserts > $3



elif [ "$1" == "extension-create-vector" ]; then
    ${DEXEC} ${MDB} "
    CREATE EXTENSION IF NOT EXISTS vector"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "extensions-show" ]; then
    ${DEXEC} ${MDB} "
    SELECT * FROM pg_extension"
# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "help" || "$1" == "h" ]]; then
    script=$(basename "$0")    
    echo "$0 - The postgres helper script!"
    echo "---------------------------------------------------------------------------------------------------"
    echo "Usage:"
    echo "$script parameter"
    echo ""
    echo "Parameters:"
    echo "check-connection                 check connection"
    echo "db-show                          show all databases"
    echo "db-create                        create database"
    echo "db-store file                    dump entire database (${DBNAME}) to file"
    echo "db-restore file                  restore database from file"
    echo "db-drop                          drop (delete) entire database (${DBNAME})"
    echo ""
    echo "tables-show                      (t) show all tables from database (${DBNAME}) with row count and size"
    echo "table-count name                 (c) count rows from name"
    echo "table-create name                create a table with name"
    echo "table-create-vector name         create a table with name, with a column from type vector"
    echo "table-show-columns name          show columns of a table"
    echo "table-store table file           table table to file"
    echo "table-restore file               restore table from file"
    echo "tables-store folder              store all tables in (${DBNAME}) to a folder"
    echo "tables-restore folder            restore all tables from a folder"
    echo "table-drop name                  drop (delete) the table name"
    echo "tables-drop-all                  drop (delete) all tables"
    echo "table-truncate name              truncate (empty) the table name"
    echo ""
    echo "select name                      (s) select some data from name"
    echo "exec query                       (e) execute a query. Query-String like: 'select * from \"my_table\" limit 10'"
    echo "dump-table-inserts table file    dump table to file (as inserts)"
    echo "extension-create-vector          create vector extension"
    echo "extensions-show                  show installed extensions"
    echo "help                             (h) show this help"
    echo ""
# ---------/---------/---------/---------/---------/---------/---------/---------/

# ---------/---------/---------/---------/---------/---------/---------/---------/
else
    clear;

    printf "\033[1;34m--- Idle connections by user ---\033[0m \n"
    ${DEXEC} ${MDB} "
        SELECT
            datname,
            usename,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE state = 'active') AS active,
            COUNT(*) FILTER (WHERE state = 'idle') AS idle,
            MAX(now() - backend_start) AS max_connection_age,
            MAX(now() - state_change) FILTER (WHERE state = 'idle') AS max_idle_age
        FROM pg_stat_activity
        GROUP BY datname, usename
        ORDER BY total DESC;
    ";


    printf "\033[1;34m--- Connections age ---\033[0m \n"
    ${DEXEC} ${MDB} "
        SELECT
            pid,
            usename,
            datname,
            backend_start,
            now() - backend_start AS connection_age
        FROM pg_stat_activity
        ORDER BY connection_age DESC
        LIMIT 100;
    ";

    printf "\033[1;34m--- Cache efficiency ---\033[0m \n"
    ${DEXEC} ${MDB} "
        SELECT
        sum(blks_hit)  AS hits,
        sum(blks_read) AS reads,
        round(100.0 * sum(blks_hit) /
                NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) AS hit_ratio
        FROM pg_stat_database;
    ";

    printf "\033[1;34m--- Rollbacks ---\033[0m \n"
    ${DEXEC} ${MDB} "
        SELECT
        datname,
        xact_commit,
        xact_rollback
        FROM pg_stat_database
        ORDER BY xact_rollback DESC;
    ";

    printf "\033[1;34m--- Active Jobs ---\033[0m \n"
    ${DEXEC} ${MDB} "
        SELECT
            pid,
            usename        AS user_name,
            datname        AS database_name,
            client_addr,
            client_port,
            -- application_name,
            state,
            -- backend_start,
            query_start
            -- wait_event_type,
            -- wait_event,
            -- query
        FROM pg_stat_activity
        WHERE datname = current_database()
        ORDER BY backend_start;
    ";

    # printf "\033[1;34m--- Long running queries ---\033[0m \n"
    # ${DEXEC} ${MDB} "
    #     SELECT
    #         pid,
    #         usename        AS user_name,
    #         datname        AS database_name,
    #         now() - query_start AS runtime,
    #         state,
    #         wait_event_type,
    #         wait_event,
    #         query
    #     FROM pg_stat_activity
    #     WHERE state = 'active'
    #     ORDER BY runtime DESC
    #     LIMIT 10;
    # ";



    exit
fi
