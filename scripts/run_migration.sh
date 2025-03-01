#!/bin/bash
set -e

echo "Starting SQL Server to SQLite migration..."

# Wait for SQL Server to be available
echo "Waiting for SQL Server to be ready..."
sleep 30
for i in {1..50}; do
    /opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P StrongPassword123! -Q "SELECT 1" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "SQL Server is ready!"
        break
    fi
    echo "Waiting for SQL Server to start... ($i)"
    sleep 2
done

# Restore the database
echo "Restoring SQL Server backup..."
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P StrongPassword123! -Q "RESTORE DATABASE RealEstateData FROM DISK = '/data/RealEstateData.bak' WITH MOVE 'RealEstateData' TO '/var/opt/mssql/data/RealEstateData.mdf', MOVE 'RealEstateData_log' TO '/var/opt/mssql/data/RealEstateData_log.ldf'"

# Get list of tables
echo "Getting list of tables..."
/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P StrongPassword123! -Q "SELECT TABLE_NAME FROM RealEstateData.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'" -o /data/tables.txt -h-1

# Export each table using BCP
echo "Exporting tables using BCP..."
while read -r table; do
    if [ -z "$table" ]; then
        continue
    fi
    echo "Exporting table: $table"
    
    # Export data
    /opt/mssql-tools/bin/bcp "RealEstateData.dbo.$table" out "/data/$table.dat" -c -U sa -P StrongPassword123! -S sqlserver
    
    # Create format file
    /opt/mssql-tools/bin/bcp "RealEstateData.dbo.$table" format nul -c -f "/data/$table.fmt" -U sa -P StrongPassword123! -S sqlserver
done < /data/tables.txt

# Run the Python conversion script
echo "Converting to SQLite..."
python /app/convert_to_sqlite.py

echo "Migration completed successfully!"
echo "Your SQLite database is available at: /data/RealEstateData.db"

# Keep container running for debugging if needed
tail -f /dev/null