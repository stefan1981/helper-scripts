#!/bin/bash

# check if .env file exists in the current folder
if [ ! -f ".env" ]; then
    echo "This script can only be executed in a folder that contains a .env file"
    echo "with the values CLICKHOUSE_DB, CLICKHOUSE_USER, CLICKHOUSE_PASSWORD"
    exit 0
fi

source .env

# check if environment variables exist
if [ -z "${CLICKHOUSE_DB}" ] || [ -z "${CLICKHOUSE_USER}" ] || [ -z "${CLICKHOUSE_PASSWORD}" ]; then
    echo "Check that this values exist in .env file: CLICKHOUSE_DB, CLICKHOUSE_USER, CLICKHOUSE_PASSWORD"
    exit 0  # Exit with an error code
fi

DBNAME=${CLICKHOUSE_DB}
USER=${CLICKHOUSE_USER}
PASSWORD=${CLICKHOUSE_PASSWORD}


DEXEC="docker exec -i datastore-clickhouse"
MDB="clickhouse-client --user ${CLICKHOUSE_USER} --password ${CLICKHOUSE_PASSWORD}"


# dump general database
DB_NAME=general2


if [ "$1" == "user-info" ]; then
    echo ""
    echo "Users:"
    ${DEXEC} ${MDB} --query "
        SELECT name, storage, auth_type, auth_params, host_ip, host_names, default_roles_all, default_roles_list, default_roles_except FROM system.users FORMAT PrettyCompact"

    echo ""
    echo "Grants. Privileges granted to ClickHouse user accounts:"
    ${DEXEC} ${MDB} --query "
        SELECT * FROM system.grants FORMAT PrettyCompact"

    echo ""
    echo "Quotas:"
    ${DEXEC} ${MDB} --query "
        SELECT * FROM system.quotas FORMAT PrettyCompact"

    echo ""
    echo "Quota consumption for all users:"
    ${DEXEC} ${MDB} --query "
        SELECT quota_name, quota_key, is_current, queries, max_queries, errors, result_rows, result_bytes, read_rows, read_bytes, execution_time FROM system.quotas_usage FORMAT PrettyCompact"

    echo ""
    echo "Show Access:"
    ${DEXEC} ${MDB} --query "
        SHOW ACCESS FORMAT PrettyCompact"

elif [ "$1" == "db-show" ]; then
    ${DEXEC} ${MDB} --query "
        -- SHOW DATABASES;
        SELECT
            d.name, formatReadableSize(sum(p.bytes_on_disk)) as size, d.engine, d.data_path,
            d.metadata_path,
            -- d.uuid 
        FROM system.databases d LEFT JOIN system.parts p ON d.name = p.database
        GROUP BY d.name, d.engine, d.data_path, d.metadata_path, d.uuid 
        ORDER BY sum(p.bytes_on_disk) DESC FORMAT PrettyCompact;        
    "

elif [ "$1" == "db-create" ]; then
    ${DEXEC} ${MDB} --query "CREATE DATABASE $2;"

elif [ "$1" == "db-drop" ]; then
    ${DEXEC} ${MDB} --query "DROP DATABASE IF EXISTS $2;"

elif [ "$1" == "tables-show" ]; then
    ${DEXEC} ${MDB} --query "
        SELECT
            database,
            name,
            engine,
            total_rows,
            formatReadableSize(total_bytes) AS size
        FROM system.tables
        WHERE database = '$DBNAME'
        ORDER BY total_bytes DESC
        FORMAT Pretty;
    "

elif [ "$1" == "table-create-example" ]; then
    ${DEXEC} ${MDB} --query "
        CREATE TABLE $DBNAME.$2 (
            id UInt32,
            name String,
            age UInt8,
            created_at DateTime
        )
        ENGINE = MergeTree()
        ORDER BY id;
    "
elif [ "$1" == "table-create-example2" ]; then
    ${DEXEC} ${MDB} --query "
        CREATE TABLE $DBNAME.$2 (
            id UUID DEFAULT generateUUIDv4(),
            text String
        )
        ENGINE = MergeTree()
        ORDER BY id;
    "

elif [ "$1" == "table-truncate" ]; then
    ${DEXEC} ${MDB} --query "TRUNCATE TABLE IF EXISTS $DBNAME.$2"


elif [ "$1" == "table-drop" ]; then
    ${DEXEC} ${MDB} --query "DROP TABLE IF EXISTS $DBNAME.$2;"

elif [ "$1" == "table-describe" ]; then
    ${DEXEC} ${MDB} --query "
        DESCRIBE TABLE $DBNAME.$2
        FORMAT Pretty;
    "

elif [ "$1" == "insert-lines" ] || [ "$1" = "i" ]; then
    # Read from stdin and insert into ClickHouse
    # Adjust table name and column list
    ${DEXEC} ${MDB} --query "
        INSERT INTO $DBNAME.$2 (text)
        FORMAT LineAsString
    " < /dev/stdin

elif [ "$1" == "select" ] || [ "$1" = "s" ]; then
    if [ -z "$2" ]; then
        echo "You must pass a tablename as parameter"
        exit 0
    fi

    if [ -n "$3" ]; then
        ${DEXEC} ${MDB} --query "
            SELECT * from $DBNAME.$2
            WHERE text LIKE '%$3%'
        "
    else
        ${DEXEC} ${MDB} --query "
            SELECT * from $DBNAME.$2
            LIMIT 1000
        "
    fi


elif [ "$1" == "exec" ]; then
    shift
    SQL="$*"
    ${DEXEC} ${MDB} --query "$SQL"



elif [ "$1" == "dump" ]; then
    echo "dump general database into file (my_general.sql)"
    #${DEXEC} mariadb-dump -u root -p${MYSQL_PASSWORD} general > my_general.sql
    #${DEXEC} ${MDB} --query "BACKUP TABLE general.test01 TO 'test.sql'"

elif [ "$1" == "restore" ]; then
    echo "restore my_general.sql into database general2 (delete general2 before)"
    #${DEXEC} ${MDB} -e "DROP DATABASE IF EXISTS ${DB_NAME}"
    #${DEXEC} ${MDB} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
    #cat my_general.sql | ${DEXEC} ${MDB} ${DB_NAME}


elif [ "$1" == "show-grants" ]; then
    ${DEXEC} ${MDB} --query "
        SHOW GRANTS FOR $2
        FORMAT Pretty;
    "

elif [ "$1" == "grant-all-privileges" ]; then
    #${DEXEC} ${MDB} --query "GRANT ALL PRIVILEGES ON $2.* TO '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

elif [ "$1" == "revoke-all-privileges" ]; then
    #${DEXEC} ${MDB} --query "REVOKE ALL PRIVILEGES ON $2.* FROM '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

elif [ "$1" == "help" ]; then
    script=$(basename "$0")    
    echo "Usage:"
    # echo "$script db-info-general                    # show general db infos"
    echo "$script user-info                          # show general user infos"
    echo "$script db-show                            # show all dbs"
    echo "$script db-create db                       # create the db with the name db"
    echo "$script db-drop db                         # drop the db with the name db"
    echo "$script tables-show                        # show tables in db"
    echo "$script table-create-example table         # create example table in db (id, name, age, created_at)"
    echo "$script table-create-example2 table        # create example table in db (id, text)"
    echo "$script table-truncate table               # truncate table in db"
    echo "$script table-drop table                   # drop table in db"
    echo "$script table-describe table               # describe table in db"

    echo "$script insert-lines table < command       # insert into a table"
    echo "$script select table [search]              # select data from a table, optional you can pass a searchterm"
    echo "$script exec sql                           # execute an arbitrary sql command"

    echo "todo $script dump                          # store db general to my_general.sql file"
    echo "todo $script restore                       # restore my_general.sql file to general2 db"    
    echo "$script show-grants user                   # show all grants of a specific user"
    echo "todo $script grant-all-privileges db user  # grant all privileges for user on db"
    echo "todo $script revoke-all-privileges db user # revoke all privileges for user on db"
    exit 1
else
    ${DEXEC} ${MDB} --query "SELECT 'Clickhouse Version: ' || version();"
    ${DEXEC} ${MDB} --query "SELECT 'Hostname: ' || hostName() ;"

    echo ""
    echo "ClickHouse disks:"
    ${DEXEC} ${MDB} --query "
        SELECT
          name, path, formatReadableSize(sum(free_space)) as free_space,
          formatReadableSize(sum(total_space)) as total_space, formatReadableSize(sum(keep_free_space)) as keep_free_space, type
        FROM system.disks
        GROUP BY name, path, type FORMAT PrettyCompact;"

    echo ""
    echo "Storage policies and volumes:"
    ${DEXEC} ${MDB} --query "
        SELECT
            policy_name, volume_name, volume_priority, disks, volume_type, load_balancing
        FROM system.storage_policies FORMAT PrettyCompact;"

    echo ""
    echo "Error codes with the number of times they have been triggered:"
    ${DEXEC} ${MDB} --query "
        SELECT name, last_error_time, last_error_message FROM system.errors FORMAT PrettyCompact"
    

    echo ""
    echo "Tables compress ratio:"
    ${DEXEC} ${MDB} --query "
    SELECT database, table, count(*) AS parts,
        uniq(partition) AS partitions,
        sum(marks) AS marks,
        sum(rows) AS rows,
        formatReadableSize(sum(data_compressed_bytes)) AS compressed,
        formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
        round((sum(data_compressed_bytes) / sum(data_uncompressed_bytes)) * 100., 2) AS percentage
    FROM system.parts WHERE active='1'
    GROUP BY database, table 
    ORDER BY rows DESC
    LIMIT 50 FORMAT PrettyCompact"

    echo ""
    echo "Top tables by size:"
    ${DEXEC} ${MDB} --query "
    SELECT database, name, engine, storage_policy, total_rows as rows, formatReadableSize(sum(total_bytes)) as size, is_temporary, metadata_modification_time
    FROM system.tables 
    --WHERE database != 'system' 
    WHERE total_rows > 0
    GROUP BY database, name, engine, is_temporary, metadata_modification_time, storage_policy, total_rows, total_bytes
    ORDER BY sum(total_bytes) DESC 
    LIMIT 20 FORMAT PrettyCompact"
    exit 1
fi
