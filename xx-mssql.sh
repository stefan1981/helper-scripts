#!/bin/bash

# check if .env file exists in the current folder
if [ ! -f ".env" ]; then
    echo "This script can only be executed in a folder that contains a .env file"
    echo "with the values MSSQL_DATABASE, MSSQL_USER, MSSQL_PASSWORD, MSSQL_CONTAINER_NAME"
    exit 0
fi

source .env

# check if environment variables exist
if [ -z "${MSSQL_DATABASE}" ] || [ -z "${MSSQL_USER}" ] || [ -z "${MSSQL_PASSWORD}" ] || [ -z "${MSSQL_CONTAINER_NAME}" ]; then
    echo "Check that this values exist in .env file: MSSQL_DATABASE, MSSQL_USER, MSSQL_PASSWORD, MSSQL_CONTAINER_NAME"
    exit 0
fi

DBNAME=${MSSQL_DATABASE}
USER=${MSSQL_USER}
PASSWORD=${MSSQL_PASSWORD}
CONTAINER_NAME=${MSSQL_CONTAINER_NAME}

# sqlcmd path inside container — override with MSSQL_SQLCMD in .env if needed
# /opt/mssql-tools18/bin/sqlcmd (mssql-server 2022+) or /opt/mssql-tools/bin/sqlcmd (older)
SQLCMD=${MSSQL_SQLCMD:-/opt/mssql-tools18/bin/sqlcmd}

DEXEC="docker exec -i ${CONTAINER_NAME}"
# -C trust server cert, -N encrypt, -b exit on error,
# -W trim trailing whitespace (tight columns), -w 1024 wider line buffer,
# -s "  " two-space column separator for readable spacing
# (arrays — needed so the two-space -s value survives word-splitting)
MDB=("${SQLCMD}" -S localhost -U "${USER}" -P "${PASSWORD}" -d "${DBNAME}" -C -N -b -Y 50)
# server-level commands (login to master, which always exists)
MDB_MASTER=("${SQLCMD}" -S localhost -U "${USER}" -P "${PASSWORD}" -d master -C -N -b -Y 50)
# headerless plain output
MDB2=("${SQLCMD}" -S localhost -U "${USER}" -P "${PASSWORD}" -d "${DBNAME}" -C -N -b -h -1 -Y 50)



if [ "$1" == "check-connection" ]; then
    echo "..."
    ${DEXEC} "${MDB_MASTER[@]}" -Q "SELECT @@VERSION;"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-show" ]; then
    ${DEXEC} "${MDB_MASTER[@]}" -Q "
        SELECT
            d.name                             AS database_name,
            d.state_desc                       AS state,
            SUSER_SNAME(d.owner_sid)           AS owner,
            d.collation_name                   AS collation,
            d.recovery_model_desc              AS recovery_model,
            CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(10,2)) AS size_mb
        FROM sys.databases d
        LEFT JOIN sys.master_files mf ON d.database_id = mf.database_id
        GROUP BY d.name, d.state_desc, d.owner_sid, d.collation_name, d.recovery_model_desc
        ORDER BY size_mb DESC;"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-create" ]; then
    ${DEXEC} "${MDB[@]}" -d master -Q "CREATE DATABASE [${DBNAME}];"
    echo "Database ${DBNAME} created"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-drop" ]; then
    ${DEXEC} "${MDB[@]}" -d master -Q "
        ALTER DATABASE [${DBNAME}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [${DBNAME}];"
    echo "Database ${DBNAME} dropped"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-store" ]; then
    # $2 = path on host to write the .bak to
    # backup runs server-side, then we copy out of the container
    BACKUP_IN_CONTAINER="/var/opt/mssql/backup/${DBNAME}.bak"
    ${DEXEC} mkdir -p /var/opt/mssql/backup
    ${DEXEC} "${MDB[@]}" -d master -Q "
        BACKUP DATABASE [${DBNAME}]
        TO DISK = N'${BACKUP_IN_CONTAINER}'
        WITH FORMAT, INIT, COMPRESSION, STATS = 10;"
    docker cp "${CONTAINER_NAME}:${BACKUP_IN_CONTAINER}" "$2"
    ${DEXEC} rm -f "${BACKUP_IN_CONTAINER}"
    echo "Database dumped to $2"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "db-restore" ]; then
    # $2 = host path to a .bak file
    BACKUP_IN_CONTAINER="/var/opt/mssql/backup/restore.bak"
    ${DEXEC} mkdir -p /var/opt/mssql/backup
    docker cp "$2" "${CONTAINER_NAME}:${BACKUP_IN_CONTAINER}"
    ${DEXEC} "${MDB[@]}" -d master -Q "
        ALTER DATABASE [${DBNAME}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        RESTORE DATABASE [${DBNAME}]
        FROM DISK = N'${BACKUP_IN_CONTAINER}'
        WITH REPLACE, STATS = 10;
        ALTER DATABASE [${DBNAME}] SET MULTI_USER;"
    ${DEXEC} rm -f "${BACKUP_IN_CONTAINER}"
    echo "Database restored from $2"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "tables-show" || "$1" == "t" ]]; then
    # optional $2 = database name; defaults to ${DBNAME} from .env
    DB="${2:-$DBNAME}"
    ${DEXEC} "${MDB_MASTER[@]}" -Q "
        USE [${DB}];
        SELECT
            DB_NAME()                          AS database_name,
            s.name                             AS [schema],
            t.name                             AS table_name,
            p.rows                             AS row_count,
            CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(10,2)) AS size_mb
        FROM sys.tables t
        INNER JOIN sys.schemas s          ON t.schema_id = s.schema_id
        INNER JOIN sys.indexes i          ON t.object_id = i.object_id
        INNER JOIN sys.partitions p       ON i.object_id = p.object_id AND i.index_id = p.index_id
        INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
        WHERE i.index_id IN (0,1)
        GROUP BY s.name, t.name, p.rows
        ORDER BY size_mb DESC;"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "table-count" || "$1" == "c" ]]; then
    ${DEXEC} "${MDB[@]}" -Q "SELECT COUNT(*) FROM [$2];"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-create" ]; then
    ${DEXEC} "${MDB[@]}" -Q "
        CREATE TABLE [$2] (
            id INT IDENTITY(1,1) PRIMARY KEY,
            name NVARCHAR(100) NOT NULL,
            email NVARCHAR(255) NOT NULL UNIQUE,
            created_at DATETIME2 DEFAULT SYSUTCDATETIME()
        );"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-show-columns" ] || [ "$1" == "table-describe" ]; then
    ${DEXEC} "${MDB[@]}" -Q "
        SELECT
            c.name                             AS column_name,
            t.name                             AS data_type,
            c.max_length,
            c.precision,
            c.scale,
            c.is_nullable,
            c.is_identity
        FROM sys.columns c
        INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
        WHERE c.object_id = OBJECT_ID('$2')
        ORDER BY c.column_id;"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-drop" ]; then
    ${DEXEC} "${MDB[@]}" -Q "DROP TABLE IF EXISTS [$2];"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "tables-drop-all" ]; then
    ${DEXEC} "${MDB[@]}" -Q "
        DECLARE @sql NVARCHAR(MAX) = N'';
        -- drop foreign keys first to avoid dependency errors
        SELECT @sql += 'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id))
                    + '.' + QUOTENAME(OBJECT_NAME(parent_object_id))
                    + ' DROP CONSTRAINT ' + QUOTENAME(name) + ';' + CHAR(10)
        FROM sys.foreign_keys;
        SELECT @sql += 'DROP TABLE ' + QUOTENAME(SCHEMA_NAME(schema_id))
                    + '.' + QUOTENAME(name) + ';' + CHAR(10)
        FROM sys.tables;
        EXEC sp_executesql @sql;"
    echo "All tables dropped"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "table-truncate" ]; then
    ${DEXEC} "${MDB[@]}" -Q "TRUNCATE TABLE [$2];"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "select" || "$1" == "s" ]]; then
    ${DEXEC} "${MDB[@]}" -Q "SELECT TOP 15 * FROM [$2];"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "exec-query" || "$1" == "e" ]]; then
    shift
    SQL="$*"
    ${DEXEC} "${MDB[@]}" -Q "$SQL"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "exec-file" || "$1" == "ef" ]]; then
    # $2 = host path to .sql file
    cat "$2" | ${DEXEC} "${MDB[@]}"
    echo "Executed SQL from file: $2"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "users-show" ]; then
    ${DEXEC} "${MDB[@]}" -Q "
        SELECT
            name, type_desc, default_schema_name, create_date, modify_date
        FROM sys.database_principals
        WHERE type IN ('S','U','G')
          AND name NOT LIKE '##%'
        ORDER BY name;"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "show-grants" ]; then
    ${DEXEC} "${MDB[@]}" -Q "
        SELECT
            dp.permission_name,
            dp.state_desc,
            dp.class_desc,
            COALESCE(OBJECT_SCHEMA_NAME(dp.major_id) + '.' + OBJECT_NAME(dp.major_id), '') AS object_name
        FROM sys.database_permissions dp
        INNER JOIN sys.database_principals u ON dp.grantee_principal_id = u.principal_id
        WHERE u.name = '$2'
        ORDER BY dp.class_desc, object_name, dp.permission_name;"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "grant-all-privileges" ]; then
    # $2 = user, $3 = role (default: db_owner)
    ROLE="${3:-db_owner}"
    ${DEXEC} "${MDB[@]}" -Q "ALTER ROLE [${ROLE}] ADD MEMBER [$2];"
    echo "User $2 added to role ${ROLE}"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [ "$1" == "revoke-all-privileges" ]; then
    # $2 = user, $3 = role (default: db_owner)
    ROLE="${3:-db_owner}"
    ${DEXEC} "${MDB[@]}" -Q "ALTER ROLE [${ROLE}] DROP MEMBER [$2];"
    echo "User $2 removed from role ${ROLE}"

# ---------/---------/---------/---------/---------/---------/---------/---------/
elif [[ "$1" == "help" || "$1" == "h" ]]; then
    script=$(basename "$0")
    echo "$0 - The mssql helper script!"
    echo "---------------------------------------------------------------------------------------------------"
    echo "Usage:"
    echo "$script parameter"
    echo ""
    echo "Parameters:"
    echo "check-connection                 check connection / show server version"
    echo "db-show                          show all databases with size"
    echo "db-create                        create database (${DBNAME})"
    echo "db-drop                          drop (delete) database (${DBNAME})"
    echo "db-store file                    backup database (${DBNAME}) to .bak file on host"
    echo "db-restore file                  restore database (${DBNAME}) from .bak file"
    echo ""
    echo "tables-show [db]                 (t) show tables with row count and size (defaults to ${DBNAME})"
    echo "table-count name                 (c) count rows of table"
    echo "table-create name                create an example table"
    echo "table-show-columns name          (table-describe) show columns of a table"
    echo "table-drop name                  drop (delete) a table"
    echo "tables-drop-all                  drop all tables in the database"
    echo "table-truncate name              truncate (empty) a table"
    echo ""
    echo "select name                      (s) select TOP 15 from a table"
    echo "exec-query query                 (e) execute an arbitrary T-SQL statement"
    echo "exec-file file                   (ef) execute T-SQL from a file"
    echo ""
    echo "users-show                       show database users"
    echo "show-grants user                 show permissions of a database user"
    echo "grant-all-privileges user [role] add user to role (default db_owner)"
    echo "revoke-all-privileges user [role] remove user from role (default db_owner)"
    echo "help                             (h) show this help"
    echo ""

# ---------/---------/---------/---------/---------/---------/---------/---------/
else
    clear

    printf "\033[1;34m--- Server version ---\033[0m \n"
    ${DEXEC} "${MDB_MASTER[@]}" -Q "SELECT @@VERSION AS version;"

    printf "\033[1;34m--- Active sessions ---\033[0m \n"
    ${DEXEC} "${MDB_MASTER[@]}" -Q "
        SELECT
            session_id, login_name, host_name, program_name,
            status, cpu_time, memory_usage, total_elapsed_time, last_request_end_time
        FROM sys.dm_exec_sessions
        WHERE is_user_process = 1
        ORDER BY last_request_end_time DESC;"

    printf "\033[1;34m--- Connections by database ---\033[0m \n"
    ${DEXEC} "${MDB_MASTER[@]}" -Q "
        SELECT
            DB_NAME(database_id) AS database_name,
            COUNT(*)             AS total,
            SUM(CASE WHEN status = 'running'  THEN 1 ELSE 0 END) AS running,
            SUM(CASE WHEN status = 'sleeping' THEN 1 ELSE 0 END) AS sleeping
        FROM sys.dm_exec_sessions
        WHERE is_user_process = 1
        GROUP BY database_id
        ORDER BY total DESC;"

    printf "\033[1;34m--- Database file sizes ---\033[0m \n"
    ${DEXEC} "${MDB_MASTER[@]}" -Q "
        SELECT
            DB_NAME(database_id) AS database_name,
            type_desc,
            name AS logical_name,
            CAST(size * 8.0 / 1024 AS DECIMAL(10,2)) AS size_mb
        FROM sys.master_files
        ORDER BY database_id, type_desc;"

    printf "\033[1;34m--- Buffer cache hit ratio ---\033[0m \n"
    ${DEXEC} "${MDB_MASTER[@]}" -Q "
        SELECT
            (CAST((SELECT cntr_value FROM sys.dm_os_performance_counters
                   WHERE counter_name = 'Buffer cache hit ratio'
                     AND object_name LIKE '%Buffer Manager%') AS FLOAT) /
             NULLIF((SELECT cntr_value FROM sys.dm_os_performance_counters
                     WHERE counter_name = 'Buffer cache hit ratio base'
                       AND object_name LIKE '%Buffer Manager%'), 0)) * 100 AS hit_ratio_pct;"

    # only show top tables if the configured database exists
    DB_EXISTS=$(${DEXEC} "${MDB_MASTER[@]}" -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = '${DBNAME}';" | tr -d '[:space:]')
    if [ "${DB_EXISTS}" = "1" ]; then
    printf "\033[1;34m--- Top tables in current db (${DBNAME}) ---\033[0m \n"
    ${DEXEC} "${MDB[@]}" -Q "
        SELECT TOP 20
            s.name AS [schema],
            t.name AS table_name,
            p.rows AS row_count,
            CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(10,2)) AS size_mb
        FROM sys.tables t
        INNER JOIN sys.schemas s          ON t.schema_id = s.schema_id
        INNER JOIN sys.indexes i          ON t.object_id = i.object_id
        INNER JOIN sys.partitions p       ON i.object_id = p.object_id AND i.index_id = p.index_id
        INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
        WHERE i.index_id IN (0,1)
        GROUP BY s.name, t.name, p.rows
        ORDER BY size_mb DESC;"
    else
        printf "\033[1;33m(database '${DBNAME}' does not exist yet — run 'db-create' to create it)\033[0m\n"
    fi

    exit
fi
