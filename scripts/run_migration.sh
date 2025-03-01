#!/bin/bash
set -e

echo "Starting SQL Server to SQLite migration..."

# Wait for SQL Server to be ready
echo "Waiting for SQL Server to be ready..."
sleep 10
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA_PASSWORD" -Q "SELECT 1" &> /dev/null; then
        echo "SQL Server is ready!"
        break
    else
        echo "SQL Server is not ready yet. Waiting..."
        sleep 2
        let RETRY_COUNT=RETRY_COUNT+1
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Timed out waiting for SQL Server to be ready"
    exit 1
fi

# Check if backup file exists
if [ ! -f /data/RealEstateData.bak ]; then
    echo "ERROR: SQL Server backup file not found at /data/RealEstateData.bak"
    exit 1
fi

# Get SQL Server version
echo "Getting SQL Server version..."
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA_PASSWORD" -Q "SELECT @@VERSION" -W -h -1

# Using hardcoded logical file names
DATA_FILE="RealEstate"
LOG_FILE="RealEstate_log"
echo "Using logical files: DATA_FILE=$DATA_FILE, LOG_FILE=$LOG_FILE"

# Restore database
echo "Restoring database from backup..."
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA_PASSWORD" -Q "RESTORE DATABASE RealEstateData FROM DISK = '/data/RealEstateData.bak' WITH MOVE '$DATA_FILE' TO '/var/opt/mssql/data/RealEstateData.mdf', MOVE '$LOG_FILE' TO '/var/opt/mssql/data/RealEstateData_log.ldf', REPLACE" || {
    echo "Failed to restore database. Creating empty database instead."
    /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA_PASSWORD" -Q "CREATE DATABASE RealEstateData"
}

# Check if database was created
echo "Checking if database was created..."
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA_PASSWORD" -Q "SELECT name FROM sys.databases WHERE name = 'RealEstateData'"

# Get list of tables - Use format that's easier to parse
echo "Getting list of tables..."
mkdir -p /data/format
mkdir -p /data/out

# Save the list of tables to a file, with a format that's easier to parse
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P "$SA_PASSWORD" -Q "SET NOCOUNT ON; SELECT TABLE_NAME FROM RealEstateData.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" -o /data/tables.txt

# Improved table name filtering - add more rigorous checks
echo "Processing tables from list..."
grep -v "^\s*$" /data/tables.txt | grep -v "^-\+$" | grep -v "TABLE_NAME" | grep -v "affected)" | while read line; do
    # Remove leading/trailing whitespace
    table=$(echo "$line" | xargs)
    
    # Skip empty table names
    if [ -z "$table" ]; then
        continue
    fi
    
    # Check if table name contains invalid characters like parentheses, spaces, etc.
    if [[ "$table" =~ [[:space:]\(\)\[\]\{\}\<\>\|\,\;\:\"\'\`\@\#\$\%\^\&\*\+\=\~\?] ]]; then
        echo "Skipping invalid table name: $table"
        continue
    fi
    
    echo "Exporting table: $table"
    
    # Export schema
    /opt/mssql-tools/bin/bcp "SELECT COLUMN_NAME, DATA_TYPE FROM RealEstateData.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$table' ORDER BY ORDINAL_POSITION" queryout "/data/format/$table.fmt" -c -t"," -S sqlserver -U sa -P "$SA_PASSWORD" || {
        echo "Error exporting schema for $table"
        continue
    }
    
    # Export data
    echo "Starting copy for table $table..."
    /opt/mssql-tools/bin/bcp "RealEstateData.dbo.$table" out "/data/out/$table.dat" -S sqlserver -U sa -P "$SA_PASSWORD" -c || {
        echo "Error exporting data for $table"
        continue
    }
    
    echo "Successfully exported $table"
done

# Run Python script to convert to SQLite
echo "Converting to SQLite..."
python /app/convert_to_sqlite.py

echo "Done!"

# Keep container running for debugging if needed
# Uncomment the next line for debugging
# tail -f /dev/null