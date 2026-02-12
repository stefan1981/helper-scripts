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
PROJECT_NAME=${PROJECT_NAME}

DEXEC="docker exec -i ${PROJECT_NAME}-postgres"
MDB="psql -U ${USER} -d ${DBNAME} -c"
MDB2="psql -U ${USER} -d ${DBNAME} -t -A -X -q -c"



if [ "$1" == "check-connection" ]; then
    echo "..."
    ${DEXEC} pg_isready -U ${USER} -d ${DBNAME}

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-show" ]; then
    ${DEXEC} ${MDB} "\l"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "tables-show" ]; then
    ${DEXEC} ${MDB} "\dt"

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
elif [ "$1" == "table-drop" ]; then
    ${DEXEC} ${MDB} "
    DROP TABLE IF EXISTS \"$2\""

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "select" ]; then
    ${DEXEC} ${MDB} "
    SELECT * FROM \"$2\""

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "count" ]; then
    ${DEXEC} ${MDB} "
    SELECT count(*) FROM \"$2\""


# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "dump-table" ]; then
    ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -t $2 > $3
# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "dump-table-inserts" ]; then
    ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -t $2 --column-inserts > $3

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "dump-tables" ]; then
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
        ${DEXEC} pg_dump -U ${USER} -d ${DBNAME} -t ${tablename} > "$2/$sql_file"
    done
# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "import-sql" ]; then
    # $2 = path to .sql file
    cat $2 | ${DEXEC} psql -U ${USER} -d ${DBNAME}
# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "extension-create-vector" ]; then
    ${DEXEC} ${MDB} "
    CREATE EXTENSION IF NOT EXISTS vector"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "extensions-show" ]; then
    ${DEXEC} ${MDB} "
    SELECT * FROM pg_extension"
# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "help" || "$1" == "--help" ]]; then
    script=$(basename "$0")    
    echo "$0 - The postgres helper script!"
    echo "---------------------------------------------------------------------------------------------------"
    echo "Usage:"
    echo "$script check-connection              # A100 - check connection"
    echo "$script db-show                       # A110 - show all databases"
    echo "$script tables-show                   # A200 - show all tables"
    echo "$script table-create name             # A210 - create a table with name"
    echo "$script table-create-vector name      # A220 - create a table with name, with a column from type vector"
    echo "$script table-show-columns name       # A230 - show columns of a table"
    echo "$script table-drop name               # A240 - drop (delete) the table name"
    echo "$script select name                   # A300 - select some data from name"
    echo "$script count name                    # A310 - count rows from name"
    echo "$script dump-table table file         # A400 - dump table to file"
    echo "$script dump-table-inserts table file # A405 - dump table to file (as inserts)"
    echo "$script dump-tables folder            # A410 - dump all tables to a folder"
    echo "$script import-sql file               # A420 - import table from file"
    echo "$script extension-create-vector       # A500 - create vector extension"
    echo "$script extensions-show               # A510 - show installed extensions"
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

    printf "\033[1;34m--- Tables in database: %s ---\033[0m \n" "$DBNAME"
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
