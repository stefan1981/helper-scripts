# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A collection of Bash shell scripts for managing databases (PostgreSQL, MariaDB/MySQL, ClickHouse) running inside Docker containers. All scripts follow the same pattern: read credentials from a `.env` file, then dispatch to sub-commands via a `if/elif/else` chain on `$1`.

## Running the Scripts

All scripts must be run from a directory containing a `.env` file with the relevant credentials:

```bash
chmod +x *.sh          # make executable (one-time)
./xx-postgres.sh       # run without args to see health dashboard
./xx-postgres.sh help  # show available commands
```

Run without arguments to get a status/monitoring overview for each database. Run with `help` or `h` to see available commands.

## Architecture Pattern

Every database script (`xx-postgres.sh`, `xx-mariadb.sh`, `xx-clickhouse.sh`) follows the same structure:

1. **Guard**: exits if `.env` is missing or required vars are unset
2. **Source `.env`**: loads credentials into shell variables
3. **Build command prefixes**: e.g. `DEXEC="docker exec -i ${CONTAINER_NAME}"` and `MDB="psql -U ..."`
4. **Dispatch**: `if/elif/else` on `$1` — each branch runs `${DEXEC} ${MDB} ...` with inline SQL
5. **Default (no args)**: displays a monitoring/overview dashboard

Commands accept positional args: `$2` = table/db name, `$3` = file path, etc. Some commands accept stdin piped in (e.g. `insert-lines` in ClickHouse).

## Environment Variables

Each script requires a `.env` file in the **current working directory** (not the script's directory):

| Script | Required vars |
|--------|---------------|
| `xx-postgres.sh` | `POSTGRES_DATABASE`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_CONTAINER_NAME` |
| `xx-mariadb.sh` | `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_CONTAINER_NAME` |
| `xx-clickhouse.sh` | `CLICKHOUSE_DB`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_CONTAINER_NAME` |

## Adding New Commands

Follow the existing pattern:
1. Add a new `elif [ "$1" == "command-name" ]; then` block
2. Use `${DEXEC} ${MDB} ...` to execute inside the Docker container
3. `$2`, `$3` for positional parameters; `shift; SQL="$*"` to capture remaining args as SQL
4. Add the command to the `help` branch at the bottom
5. Update README.md with the new command

## Key Notes

- **ClickHouse tables** must use a MergeTree engine variant and require `ORDER BY`
- **PostgreSQL `dump-tables`** uses `jq` to parse JSON output — requires `jq` on the host
- `xx-aliases.sh` is sourced into shell config (not run directly); provides Docker, Kubernetes, and zsh aliases
- The GitHub Actions workflow (`.github/workflows/github-actions-demo.yml`) deploys via SSH on every push using secrets `SSH_PRIVATE_KEY_1BLUE`, `SSH_HOST_1BLUE`, `SSH_USER_1BLUE`
