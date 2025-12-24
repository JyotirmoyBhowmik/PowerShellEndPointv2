# Enterprise Endpoint Monitoring System (EMS) - Installation Guide

**Version**: 2.0 (Web Architecture)  
**Last Updated**: 2025-12-23

---

## 🌐 New Web-Based Architecture

EMS v2.0 has been modernized with a **web-based interface** accessible from any browser. The desktop WPF application has been archived.

### Architecture Components
- **Web UI**: React-based responsive interface
- **REST API**: PowerShell Universal Dashboard backend
- **Database**: PostgreSQL for centralized data storage
- **Deployment**: IIS web server with reverse proxy

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Steps](#installation-steps)
3. [Database Setup](#database-setup)
4. [API Configuration](#api-configuration)
5. [Web UI Setup](#web-ui-setup)
6. [Production Deployment](#production-deployment)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Software Requirements

#### Server/Workstation
- **Operating System**: Windows Server 2016+ or Windows 10/11
- **PowerShell**: Version 5.1 or later
- **PostgreSQL**: Version 15 or later
- **Node.js**: Version 16 or later (for building React app)
- **IIS**: Version 10+ (for production deployment)

#### PowerShell Modules
```powershell
# Install UniversalDashboard for API backend
Install-Module -Name UniversalDashboard -Force

# Install PostgreSQL driver
# Download Npgsql via NuGet (instructions in Database Setup)
```

#### Target Endpoints
- **Operating System**: Windows 10, Windows 11, Windows Server 2016+
- **PowerShell Remoting**: Enabled (`Enable-PSRemoting`)
- **WinRM Service**: Running
- **Firewall Rules**: Ports 5985 (HTTP) and 5986 (HTTPS) open

### Network Requirements

- **DNS**: Fully functional DNS resolution
- **Active Directory**: Domain-joined workstations
- **Bandwidth**: Minimum 512 Kbps for remote sites
- **Firewall Ports**:
  - TCP 80/443 (HTTP/HTTPS for web UI)
  - TCP 5000 (API backend - internal only)
  - TCP 5432 (PostgreSQL - internal only)
  - TCP 5985/5986 (WinRM to endpoints)

### Permissions Requirements

- **Local Administrator** on server
- **Domain User** account
- **Member** of `EMS_Admins` AD security group
- **Read permissions** on AD computer objects
- **Database** access (granted during setup)

---

## Installation Steps

### Step 1: Install PostgreSQL

**Download and Install**:
```powershell
# Option 1: Direct download
# Visit: https://www.postgresql.org/download/windows/
# Download PostgreSQL 15.x installer
# Run installer with default settings
# Remember the postgres user password

# Option 2: Using Chocolatey
choco install postgresql15 -y
```

**Verify Installation**:
```powershell
# Check service status
Get-Service postgresql*

# Test psql command
psql --version
```

### Step 2: Install Node.js

```powershell
# Option 1: Direct download
# Visit: https://nodejs.org/
# Download LTS version (16.x or 18.x)
# Run installer

# Option 2: Using Chocolatey
choco install nodejs-lts -y

# Verify installation
node --version
npm --version
```

### Step 3: Install Npgsql .NET Driver

```powershell
cd C:\Users\ZORO\PowerShellEndPointv2

# Create Lib directory
New-Item -Path ".\Lib" -ItemType Directory -Force

# Install via NuGet
nuget install Npgsql -OutputDirectory .\Lib -Version 7.0.6

# Verify installation
Test-Path ".\Lib\Npgsql.7.0.6\lib\net6.0\Npgsql.dll"
```

### Step 4: Install PowerShell Universal Dashboard

```powershell
# Run as Administrator
Install-Module -Name UniversalDashboard -Scope AllUsers -Force

# Verify installation
Get-Module -ListAvailable UniversalDashboard
```

---

## Database Setup

### Step 1: Create Database and User

```powershell
# Connect to PostgreSQL
psql -U postgres

# In psql prompt:
```
```sql
-- Create database
CREATE DATABASE ems_production;

-- Create service account
CREATE USER ems_service WITH ENCRYPTED PASSWORD 'YourSecurePassword123!';

-- Grant connection permissions
GRANT CONNECT ON DATABASE ems_production TO ems_service;

-- Exit psql
\q
```

### Step 2: Deploy Database Schema

```powershell
cd C:\Users\ZORO\PowerShellEndPointv2\Database

# Run schema creation script
psql -U postgres -d ems_production -f schema.sql
```

**Expected Output**: Tables created, indexes created, functions created, initial data inserted

### Step 3: Grant Permissions

```powershell
# Connect to database
psql -U postgres -d ems_production
```
```sql
-- Grant table permissions
GRANT USAGE ON SCHEMA public TO ems_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ems_service;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ems_service;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ems_service;

-- Exit
\q
```

### Step 4: Test Database Connection

```powershell
cd C:\Users\ZORO\PowerShellEndPointv2

# Import modules
Import-Module .\Modules\Logging.psm1 -Force
Import-Module .\Modules\Database\PSPGSql.psm1 -Force

# Load configuration
$config = Get-Content .\Config\EMSConfig.json | ConvertFrom-Json

# UPDATE: Set your database password in config
$config.Database.Password = "YourSecurePassword123!"

# Initialize and test
Initialize-PostgreSQLConnection -Config $config
Test-PostgreSQLConnection
```

**Expected Result**: Connection successful message with PostgreSQL version

---

## API Configuration

### Step 1: Update Configuration File

Edit `Config\EMSConfig.json`:

```json
{
  "Database": {
    "Host": "localhost",
    "Port": 5432,
    "DatabaseName": "ems_production",
    "Username": "ems_service",
    "Password": "YourSecurePassword123!",
    "ConnectionPoolSize": 20
  },
  "API": {
    "ListenAddress": "http://localhost:5000",
    "JWTSecretKey": "GENERATE_SECURE_RANDOM_KEY_32_CHARS_MINIMUM",
    "TokenExpirationMinutes": 60,
    "EnableCORS": true,
    "AllowedOrigins": ["http://localhost:3000", "http://localhost"]
  },
  "Security": {
    "AdminGroup": "EMS_Admins"
  }
}
```

**Security Note**: Generate a strong JWT secret key:
```powershell
# Generate secure random key
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

### Step 2: Create AD Security Group

```powershell
# As Domain Admin
Import-Module ActiveDirectory

New-ADGroup -Name "EMS_Admins" `
            -GroupCategory Security `
            -GroupScope Global `
            -Path "OU=Security Groups,DC=corp,DC=local" `
            -Description "Users authorized to access EMS web interface"

# Add users
Add-ADGroupMember -Identity "EMS_Admins" -Members "jsmith", "admin"
```

### Step 3: Test API Server

```powershell
# Start API in test mode
cd C:\Users\ZORO\PowerShellEndPointv2\API
.\Start-EMSAPI.ps1
```

**Expected Output**:
```
========================================
 EMS REST API Server
========================================
Address: http://localhost:5000
Endpoints:
  POST   /api/auth/login
  GET    /api/auth/validate
  POST   /api/scan/single
  GET    /api/results
  GET    /api/results/:id
  GET    /api/dashboard/stats

Press Ctrl+C to stop the server
========================================
```

**Test Authentication**:
```powershell
# In another PowerShell window
$body = @{
    username = "CORP\jsmith"
    password = "password123"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5000/api/auth/login" `
                  -Method POST `
                  -Body $body `
                  -ContentType "application/json"
```

---

## Web UI Setup

### Step 1: Install Dependencies

```powershell
cd C:\Users\ZORO\PowerShellEndPointv2\WebUI

# Install React dependencies (first time only)
npm install
```

**Expected Output**: Packages installed successfully

### Step 2: Development Testing

```powershell
# Start development server
npm start
```

**Expected Output**:
- Compiled successfully
- Opens browser at `http://localhost:3000`
- Shows login page

### Step 3: Build for Production

```powershell
# Create production build
npm run build
```

**Expected Output**: Optimized build created in `build/` directory

---

## Production Deployment

For detailed production deployment to IIS, see: **[Deployment/IIS_Setup.md](Deployment/IIS_Setup.md)**

### Quick Deployment Steps

**1. Build React App**:
```powershell
cd WebUI
npm run build
```

**2. Deploy to IIS**:
```powershell
# Create deployment directory
New-Item -Path "C:\inetpub\ems\webui" -ItemType Directory -Force

# Copy build files
Copy-Item -Path ".\build\*" -Destination "C:\inetpub\ems\webui\" -Recurse -Force
```

**3. Install API as Windows Service** (using NSSM):
```powershell
# Install NSSM
choco install nssm -y

# Install service
nssm install EMS_API powershell.exe `
    "-ExecutionPolicy Bypass -File C:\Users\ZORO\PowerShellEndPointv2\API\Start-EMSAPI.ps1"

# Start service
Start-Service EMS_API
```

**4. Configure IIS Website**:
```powershell
Import-Module WebAdministration

# Create application pool
New-WebAppPool -Name "EMS_Pool"

# Create website
New-Website -Name "EMS" `
            -PhysicalPath "C:\inetpub\ems\webui" `
            -ApplicationPool "EMS_Pool" `
            -Port 80
```

**5. Configure web.config** (for React Router and API proxy):
- See template in `Deployment/IIS_Setup.md`

**6. Configure Firewall**:
```powershell
New-NetFirewallRule -DisplayName "EMS Web - HTTP" `
    -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
```

---

## Verification

### Test Checklist

**Database**:
- [ ] PostgreSQL service running
- [ ] Database `ems_production` exists
- [ ] Schema applied (8 tables visible)
- [ ] Service user has permissions
- [ ] Connection test passes

**API Backend**:
- [ ] UniversalDashboard module installed
- [ ] API starts without errors
- [ ] Endpoints return 200/401 status codes
- [ ] JWT authentication works
- [ ] Database queries execute

**Web Frontend**:
- [ ] React dev server runs (`npm start`)
- [ ] Production build succeeds (`npm run build`)
- [ ] Login page loads
- [ ] Can authenticate with AD credentials

**Integration**:
- [ ] Login successful from web UI
- [ ] Dashboard displays statistics
- [ ] Can execute scan and see results
- [ ] Results save to PostgreSQL
- [ ] Audit logs written

---

## Troubleshooting

### Database Connection Failed

**Symptoms**: "Connection refused" or "password authentication failed"

**Solutions**:
```powershell
# Check PostgreSQL service
Get-Service postgresql*
Start-Service postgresql-x64-15

# Verify password in EMSConfig.json matches database user

# Check pg_hba.conf allows localhost connections:
# Edit: C:\Program Files\PostgreSQL\15\data\pg_hba.conf
# Add: host all all 127.0.0.1/32 md5

# Restart PostgreSQL
Restart-Service postgresql-x64-15
```

### API Fails to Start

**Symptoms**: Module errors or port already in use

**Solutions**:
```powershell
# Check if UniversalDashboard installed
Get-Module -ListAvailable UniversalDashboard

# If missing:
Install-Module UniversalDashboard -Force

# Check if port 5000 is in use
Get-NetTCPConnection -LocalPort 5000

# Change port in EMSConfig.json if needed
```

### Web UI Build Fails

**Symptoms**: npm errors during build

**Solutions**:
```powershell
# Clear npm cache
npm cache clean --force

# Delete node_modules
Remove-Item -Path "node_modules" -Recurse -Force

# Reinstall
npm install

# Retry build
npm run build
```

### Authentication Fails

**Symptoms**: "Invalid credentials" or "Unauthorized"

**Solutions**:
```powershell
# Verify user is in EMS_Admins group
Get-ADGroupMember -Identity "EMS_Admins"

# Add user if missing
Add-ADGroupMember -Identity "EMS_Admins" -Members "username"

# User must log out/in or run:
gpupdate /force
```

---

## Migrating from Legacy Desktop App

If upgrading from EMS v1.0 (WPF desktop app):

### Step 1: Archive Old Application

Legacy files have been moved to `Archive_Legacy_Desktop_App/`:
- `Invoke-EMS.ps1` (old WPF launcher)
- `MainWindow.xaml` (old UI)
- `sample_targets.csv` (example file)

These files are **no longer used** and kept for reference only.

### Step 2: Migrate CSV Logs

```powershell
# Import existing CSV logs to PostgreSQL
.\Database\migrate_csv_to_postgresql.ps1 -CSVLogPath "C:\EMSLogs"
```

### Step 3: Update Shortcuts

- **Old**: Desktop shortcut to `Invoke-EMS.ps1`
- **New**: Browser bookmark to `http://your-server/` or `https://ems.corp.local/`

---

## Next Steps

1. **Review**: [README.md](README.md) for architecture overview
2. **Deploy**: [Deployment/IIS_Setup.md](Deployment/IIS_Setup.md) for production
3. **Train**: Share web URL with administrators
4. **Monitor**: Check `Logs/` directory for errors
5. **Backup**: Schedule PostgreSQL database backups

---

## Quick Reference

### Common Commands

```powershell
# Start API (development)
.\API\Start-EMSAPI.ps1

# Start Web UI (development)
cd WebUI && npm start

# Build Web UI (production)
cd WebUI && npm run build

# Test database connection
Import-Module .\Modules\Database\PSPGSql.psm1
Test-PostgreSQLConnection

# Check API service status (production)
Get-Service EMS_API

# View API logs
Get-Content "Logs\api_stdout.log" -Tail 50
```

### Access URLs

- **Development**: http://localhost:3000
- **Production**: http://your-server or https://ems.corp.local
- **API (direct)**: http://localhost:5000

### Support Resources

- **Database Setup**: [Database/README.md](Database/README.md)
- **Deployment Guide**: [Deployment/IIS_Setup.md](Deployment/IIS_Setup.md)
- **Web UI Docs**: [WebUI/README.md](WebUI/README.md)

---

**Installation Version**: 2.0.0 (Web Architecture)  
**Document Last Updated**: 2025-12-23
