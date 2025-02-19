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

#${DEXEC} mariadb -u root -p${MYSQL_PASSWORD} -e "USE ${DB_NAME}; SHOW TABLES;"



if [ "$1" == "db-info-general" ]; then
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
    echo "Databases:"
    ${DEXEC} ${MDB} --query "
        SELECT
            d.name, formatReadableSize(sum(p.bytes_on_disk)) as size, d.engine, d.data_path,
            d.metadata_path,
            -- d.uuid 
        FROM system.databases d LEFT JOIN system.parts p ON d.name = p.database
        GROUP BY d.name, d.engine, d.data_path, d.metadata_path, d.uuid 
        ORDER BY sum(p.bytes_on_disk) DESC FORMAT PrettyCompact;"

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

elif [ "$1" == "db-info-user" ]; then
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
    ${DEXEC} ${MDB} --query "SHOW DATABASES;"

elif [ "$1" == "db-create" ]; then
    ${DEXEC} ${MDB} --query "CREATE DATABASE $2;"

elif [ "$1" == "db-drop" ]; then
    ${DEXEC} ${MDB} --query "DROP DATABASE $2;"

elif [ "$1" == "tables-show" ]; then
    ${DEXEC} ${MDB} --query "SHOW TABLES FROM $2;"

elif [ "$1" == "table-create-example" ]; then
    ${DEXEC} ${MDB} --query "CREATE TABLE $2.$3 ( id UInt32, name String, age UInt8, created_at DateTime) ENGINE = MergeTree() ORDER BY id;"

elif [ "$1" == "table-drop" ]; then
    ${DEXEC} ${MDB} --query "DROP TABLE IF EXISTS $2.$3"

elif [ "$1" == "table-describe" ]; then
    ${DEXEC} ${MDB} --query "DESCRIBE TABLE $2.$3"

elif [ "$1" == "dump" ]; then
    echo "dump general database into file (my_general.sql)"
    #${DEXEC} mariadb-dump -u root -p${MYSQL_PASSWORD} general > my_general.sql
    #${DEXEC} ${MDB} --query "BACKUP TABLE general.test01 TO 'test.sql'"

elif [ "$1" == "restore" ]; then
    echo "restore my_general.sql into database general2 (delete general2 before)"
    #${DEXEC} ${MDB} -e "DROP DATABASE IF EXISTS ${DB_NAME}"
    #${DEXEC} ${MDB} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
    #cat my_general.sql | ${DEXEC} ${MDB} ${DB_NAME}

elif [ "$1" == "show-users" ]; then
    ${DEXEC} ${MDB} --query "SELECT name FROM system.users;"


elif [ "$1" == "show-grants" ]; then
    ${DEXEC} ${MDB} --query "SHOW GRANTS FOR $2;"

elif [ "$1" == "grant-all-privileges" ]; then
    #${DEXEC} ${MDB} --query "GRANT ALL PRIVILEGES ON $2.* TO '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

elif [ "$1" == "revoke-all-privileges" ]; then
    #${DEXEC} ${MDB} --query "REVOKE ALL PRIVILEGES ON $2.* FROM '$3'@'%'; FLUSH PRIVILEGES;"
    echo $2

else
    echo "Usage:"
    echo "$0 db-info-general                    # show general db infos"
    echo "$0 db-info-user                       # show general user infos"
    echo "$0 db-show                            # show all dbs"
    echo "$0 db-create db                       # create the db with the name db"
    echo "$0 db-drop db                         # drop the db with the name db"
    echo "$0 tables-show db                     # show tables in db"
    echo "$0 table-create-example db table      # create example table in db"
    echo "$0 table-drop db                      # drop table in db"
    echo "$0 table-describe db                  # describe table in db"

    echo "todo $0 dump                          # store db general to my_general.sql file"
    echo "todo $0 restore                       # restore my_general.sql file to general2 db"
    echo "$0 show-users                         # show all users"
    echo "$0 show-grants user                   # show all grants of a specific user"
    echo "todo $0 grant-all-privileges db user  # grant all privileges for user on db"
    echo "todo $0 revoke-all-privileges db user # revoke all privileges for user on db"
    exit 1
fi
