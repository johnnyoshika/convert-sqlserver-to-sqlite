FROM python:3.9

# Install necessary tools
RUN apt-get update && apt-get install -y \
    unixodbc-dev \
    apt-transport-https \
    sqlite3 \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install SQL Server tools
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql17 mssql-tools \
    && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc

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