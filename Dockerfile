FROM python:3.11

# Install necessary tools
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    apt-transport-https \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Remove any conflicting packages that might exist
RUN apt-get update && apt-get remove -y unixodbc unixodbc-dev libodbc2 libodbcinst2 unixodbc-common || true

# Install SQL Server ODBC drivers - fixed approach
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-archive-keyring.gpg && \
    echo "deb [arch=amd64,armhf,arm64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/debian/11/prod bullseye main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools && \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc

# Set up Python environment
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy scripts
COPY scripts/ /app/

# Make scripts executable
RUN chmod +x /app/*.sh

# Run the migration script
CMD ["/app/run_migration.sh"]