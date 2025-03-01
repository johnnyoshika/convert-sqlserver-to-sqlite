import sqlite3
import pandas as pd
import os
import glob
import sys


def main():
    print("Starting SQLite conversion...")

    # Create SQLite database
    db_path = '/data/RealEstateData.db'
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    print(f"Created SQLite database at {db_path}")

    # Find all format files
    format_files = glob.glob('/data/format/*.fmt')
    print(f"Found {len(format_files)} format files")

    success_count = 0

    # Process each table
    for fmt_file in format_files:
        # Extract table name from format file path
        table_name = os.path.basename(fmt_file).replace('.fmt', '')
        print(f"Processing table: {table_name}")

        # Path to data file
        data_file = f'/data/out/{table_name}.dat'

        # Check if data file exists
        if not os.path.exists(data_file):
            print(f"Warning: Data file not found for {table_name}, skipping")
            continue

        try:
            # Read format file to get column names
            with open(fmt_file, 'r') as f:
                lines = f.readlines()

            # Skip if format file is too short or empty
            if len(lines) < 2:
                print(
                    f"Warning: Format file for {table_name} is too short, skipping")
                continue

            # Parse column names and types from format file
            columns = []
            for line in lines:
                if ',' in line:
                    parts = line.strip().split(',')
                    if len(parts) >= 2:
                        col_name = parts[0].strip()
                        col_type = parts[1].strip()
                        if col_name and col_type and col_name != 'COLUMN_NAME':
                            columns.append((col_name, col_type))

            # Skip if no columns found
            if not columns:
                print(
                    f"Warning: No columns found in format file for {table_name}, skipping")
                continue

            print(f"Found {len(columns)} columns for table {table_name}")

            # Create table
            column_defs = []
            for col_name, col_type in columns:
                # Map SQL Server types to SQLite types
                if col_type.upper() in ('INT', 'BIGINT', 'SMALLINT', 'TINYINT'):
                    sqlite_type = 'INTEGER'
                elif col_type.upper() in ('FLOAT', 'REAL', 'DECIMAL', 'NUMERIC', 'MONEY', 'SMALLMONEY'):
                    sqlite_type = 'REAL'
                elif col_type.upper() in ('DATETIME', 'DATE', 'TIME', 'DATETIME2', 'DATETIMEOFFSET', 'SMALLDATETIME'):
                    sqlite_type = 'TEXT'
                else:
                    sqlite_type = 'TEXT'

                column_defs.append(f'"{col_name}" {sqlite_type}')

            create_table_sql = f'CREATE TABLE IF NOT EXISTS "{table_name}" ({", ".join(column_defs)})'
            conn.execute(create_table_sql)

            # Try to read the data file with different delimiters if needed
            df = None
            try:
                # First try with tab delimiter
                df = pd.read_csv(data_file, delimiter='\t', names=[col[0] for col in columns],
                                 low_memory=False, encoding='utf-8', on_bad_lines='skip')
            except Exception as e:
                print(f"Failed to read with tab delimiter: {str(e)}")
                try:
                    # Try with comma delimiter
                    df = pd.read_csv(data_file, delimiter=',', names=[col[0] for col in columns],
                                     low_memory=False, encoding='utf-8', on_bad_lines='skip')
                except Exception as e:
                    print(f"Failed to read with comma delimiter: {str(e)}")
                    try:
                        # Try with pipe delimiter
                        df = pd.read_csv(data_file, delimiter='|', names=[col[0] for col in columns],
                                         low_memory=False, encoding='utf-8', on_bad_lines='skip')
                    except Exception as e:
                        print(f"Failed to read with pipe delimiter: {str(e)}")

            if df is not None and not df.empty:
                print(f"Importing {len(df)} rows into table {table_name}")
                # Write to SQLite
                df.to_sql(table_name, conn, if_exists='replace', index=False)
                success_count += 1
            else:
                print(f"Warning: No data read for table {table_name}")

        except Exception as e:
            print(f"Error processing table {table_name}: {str(e)}")

    conn.commit()
    conn.close()

    print(
        f"Conversion completed! {success_count} tables successfully imported to SQLite database.")
    print(f"SQLite database created at: {db_path}")


if __name__ == "__main__":
    main()
