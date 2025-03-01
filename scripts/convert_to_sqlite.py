import sqlite3
import pandas as pd
import os
import glob
import re
import sys


def main():
    print("Starting SQLite database creation...")

    # Create SQLite database
    sqlite_conn = sqlite3.connect('/data/RealEstateData.db')
    print("SQLite database created.")

    # Process each format file to get table structure
    format_files = glob.glob('/data/*.fmt')

    for fmt_file in format_files:
        table_name = os.path.basename(fmt_file).replace('.fmt', '')
        print(f"Processing table: {table_name}")

        # Parse format file to get column information
        columns = []
        with open(fmt_file, 'r') as f:
            lines = f.readlines()
            # Skip header lines
            # Skip the first line which contains the number of columns
            data_lines = lines[1:]

            for line in data_lines:
                parts = line.strip().split()
                if len(parts) >= 4:
                    column_name = parts[3].strip('"')
                    columns.append(column_name)

        # Read data file
        data_file = fmt_file.replace('.fmt', '.dat')

        try:
            # Read data using pandas with column names from format file
            df = pd.read_csv(
                data_file,
                delimiter='\t',
                names=columns,
                encoding='utf-8',
                on_bad_lines='skip',  # Updated parameter name for newer pandas
                low_memory=False
            )

            # Write to SQLite
            df.to_sql(table_name, sqlite_conn,
                      if_exists='replace', index=False)
            print(
                f"Table {table_name} imported successfully with {len(df)} rows.")
        except Exception as e:
            print(f"Error importing {table_name}: {str(e)}", file=sys.stderr)

    # Close connection
    sqlite_conn.close()
    print("Conversion completed successfully!")


if __name__ == "__main__":
    main()
