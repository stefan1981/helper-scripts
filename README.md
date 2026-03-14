# helper-scripts

A collection of specialized shell scripts for database management in containerized environments. All scripts are designed to work with minimal dependencies and provide comprehensive database administration capabilities.

## 📋 Overview

This repository contains three database management scripts:
- **xx-clickhouse.sh** - ClickHouse database management utilities
- **xx-mariadb.sh** - MariaDB/MySQL database management utilities  
- **xx-postgres.sh** - PostgreSQL database management utilities

## 🚀 Quick Start

1. Clone this repository
2. Make scripts executable: `chmod +x *.sh`
3. Create a `.env` file in your project directory with the required environment variables for your database
4. Run any script without parameters to see available commands and system overview

## 📁 Database Scripts Documentation

### xx-clickhouse.sh

Comprehensive ClickHouse database management script for containerized environments.

**Prerequisites:**
Create a `.env` file with:
```env
CLICKHOUSE_DB=your_database_name
CLICKHOUSE_USER=your_username
CLICKHOUSE_PASSWORD=your_password
CLICKHOUSE_CONTAINER_NAME=your_container_name
```

Run `./xx-clickhouse.sh help` to see all available commands.

**Default Information Display:**
When run without parameters, shows system overview including version, disk usage, storage policies, error statistics, compression ratios, and largest tables.

### xx-mariadb.sh

MariaDB/MySQL database management utilities for Docker containers.

**Prerequisites:**
Create a `.env` file with:
```env
MYSQL_DATABASE=your_database_name
MYSQL_USER=your_username
MYSQL_PASSWORD=your_password
MYSQL_CONTAINER_NAME=your_container_name
```

Run `./xx-mariadb.sh help` to see all available commands.

### xx-postgres.sh

PostgreSQL database management script with advanced features including vector extension support.

**Prerequisites:**
Create a `.env` file with:
```env
POSTGRES_DATABASE=your_database_name
POSTGRES_USER=your_username
POSTGRES_PASSWORD=your_password
POSTGRES_CONTAINER_NAME=your_container_name
```

Run `./xx-postgres.sh help` to see all available commands.

**System Monitoring:**
When run without parameters, displays comprehensive database health information:
- Connection statistics by user
- Connection age analysis  
- Cache hit ratio efficiency
- Transaction rollback statistics
- Table statistics with sizes and maintenance info
- Active database sessions


## 💡 Usage Examples

### Quick Database Inspection
```bash
# Check what's in your databases
./xx-clickhouse.sh              # System overview
./xx-mariadb.sh tables-show     # List tables with sizes
./xx-postgres.sh                # Health dashboard
```

### Data Pipeline Workflow
```bash
# Export data from one system
./xx-postgres.sh dump-table users users_backup.sql

# Import to another system (after conversion)
cat data.txt | ./xx-clickhouse.sh insert-lines user_logs
```

### Common Database Tasks
```bash
# Create and populate test tables
./xx-postgres.sh table-create test_table
./xx-clickhouse.sh table-create-example logs_table

# Monitor database health
./xx-postgres.sh                    # Shows health dashboard
./xx-mariadb.sh db-show             # Shows database sizes
./xx-clickhouse.sh                  # Shows system overview

# Backup important data
./xx-postgres.sh dump-tables ./backups/
./xx-mariadb.sh dump-database
```

## 🛡️ Safety Features

- **Environment validation**: All database scripts verify required environment variables
- **Confirmation prompts**: Destructive operations include safeguards
- **Error handling**: Scripts exit gracefully on missing dependencies
- **Container isolation**: All operations run inside Docker containers
- **Consistent interface**: Similar command patterns across all database scripts

## 🔍 Troubleshooting

### Common Issues

1. **"This script can only be executed in a folder that contains a .env file"**
   - Ensure you have a `.env` file in your current directory with the required variables

2. **Container connection errors**
   - Verify container names match your Docker setup
   - Check if containers are running: `docker ps`
   - Test connectivity: `./xx-postgres.sh check-connection`

3. **Permission errors**
   - Make scripts executable: `chmod +x *.sh`
   - Verify Docker container permissions

4. **Database-specific issues**
   - **ClickHouse**: Ensure proper MergeTree engine usage for tables
   - **MariaDB**: Check for proper character set configuration
   - **PostgreSQL**: Verify extensions are available in your container

## 📝 Contributing

When adding new functionality:
1. Follow the existing command pattern (`script.sh action [parameters]`)
2. Include help text in the default case statement
3. Add environment variable validation where needed
4. Update this README with new commands
5. Test with containerized database setups

## 📄 License

This project is designed for personal and development use. All scripts work independently and have minimal external dependencies beyond Docker and standard Unix utilities.
