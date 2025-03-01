# Convert SQL Server to SQLite

A Docker-based tool for converting SQL Server database backups (`.bak` files) to SQLite databases.

## Prerequisites

- Docker installed and running

## Setup

Copy `.bak` file to the `data` directory:

```bash
cp /path/to/your/RealEstateData.bak ./data/
```

## Usage

```bash
docker compose up
```

When complete, the SQLite database will be at `./data/RealEstateData.db`.

## Customiation

- For databases with different names, update references to RealEstateData in run_migration.sh
- To change SQL Server password, update it in both docker-compose.yml and run_migration.sh

## Cleanup

```bash
docker compose down -v
docker rmi convert-sqlserver-to-sqlite-migration
```
