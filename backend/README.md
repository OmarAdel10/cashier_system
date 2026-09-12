# Daftari POS - Backend Services

This directory contains the backend services for the Daftari POS (Point of Sale) system, a premium offline-first POS engine for Egyptian stationery shops.

## Architecture Overview

The backend is organized into the following modules:

### Core Backend Services (`lib/core/backend/`)

| Module | Description |
|--------|-------------|
| `auth/` | Authentication & authorization services (PBKDF2-HMAC-SHA256, JWT tokens) |
| `database/` | Database abstraction layer (Hive, migrations, sharding) |
| `api/` | REST API endpoints and middleware |
| `firebase_functions/` | Firebase Cloud Functions for cloud sync (optional) |
| `themes/` | Dynamic theming engine |
| `pricing/` | Pricing rules, discounts, tax calculations |
| `sessions/` | Session management, shift tracking |
| `sharding/` | Data sharding for multi-tenant deployments |
| `migrations/` | Schema migration utilities |
| `cloud_admin/` | Cloud administration interface |

### Platform-Specific Services (`backend/`)

| Service | Description |
|---------|-------------|
| `print_server/` | .NET 8 minimal API for thermal receipt, barcode, and ticket printing (Windows + Linux) |
| `shard_manager/` | Shard orchestration and rebalancing |
| `scripts/` | Build, deploy, and maintenance scripts |

## Print Server

The Print Server is a cross-platform .NET 8 service that handles all printing operations:

- **Thermal Receipt Printing** - ESC/POS commands for 58mm/80mm printers
- **Barcode Label Printing** - Code128, QR codes on label printers
- **PDF Invoice Generation** - A4 invoices via `POST /api/printing/save-pdf`
- **Kitchen/Bar/Shisha Tickets** - Specialized ticket formats for cafe/restaurant mode

### Endpoints

```
GET  /api/printing/local-printers     # List installed printers
POST /api/printing/print-receipt      # Print thermal receipt
POST /api/printing/print-barcode      # Print barcode label
POST /api/printing/save-pdf           # Generate & save A4 PDF invoice
POST /api/printing/kitchen-ticket     # Print kitchen ticket
POST /api/printing/bar-ticket         # Print bar ticket
POST /api/printing/shisha-ticket      # Print shisha ticket
```

### Platform Builds

- **Windows**: Self-contained `win-x64` executable
- **Linux**: Self-contained `linux-x64` executable

Managed by `PrintServerManager` / `PrintServerManagerLinux` in the Flutter app with parent-PID watchdog.

## Development

### Prerequisites

- .NET 8 SDK
- Flutter 3.24+ / Dart 3.12+

### Building Print Server

```bash
# Windows
cd PrintServer
dotnet publish -c Release -r win-x64 --self-contained true

# Linux
cd PrintServer.Linux
dotnet publish -c Release -r linux-x64 --self-contained true
```

### Running Locally

```bash
# Start print server (Windows)
./PrintServer/bin/Release/net8.0/win-x64/publish/PrintServer.exe

# Start print server (Linux)
./PrintServer.Linux/bin/Release/net8.0/linux-x64/publish/PrintServer
```

## Configuration

Backend services are configured via:
- `appsettings.json` (Print Server)
- Environment variables
- Flutter app settings (Hive boxes)

## Testing

```bash
# Print Server tests
cd PrintServer.Tests
dotnet test

cd PrintServer.Linux.Tests
dotnet test
```

## Deployment

The backend services are deployed alongside the Flutter desktop application:

1. Print Server executables bundled in Flutter build output
2. `PrintServerManager` starts/stops the sidecar process
3. Communication via localhost REST API (default port 5000)

## License

Proprietary - Daftari POS System