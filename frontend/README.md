# Daftari POS - Frontend Applications

This directory contains the frontend applications for the Daftari POS system.

## Applications

### Landing Page (`landing_page/`)

Marketing landing page for the Daftari POS product.

- **Tech Stack**: Flutter Web / Stitch-generated components
- **Purpose**: Product showcase, feature highlights, download links
- **Deployment**: Static hosting (Firebase Hosting, Vercel, Netlify)

### Admin Dashboard (`admin_dashboard/`)

Web-based administration panel for multi-store management.

- **Tech Stack**: Flutter Web
- **Features**:
  - Multi-store overview
  - Sales analytics & reporting
  - Inventory management across locations
  - User & role management
  - License management
  - Settings synchronization

## Development

### Prerequisites

- Flutter 3.24+ / Dart 3.12+
- Stitch CLI (for design-to-code workflow)

### Running Locally

```bash
# Landing page
cd landing_page
flutter run -d chrome --web-port 8080

# Admin dashboard
cd admin_dashboard
flutter run -d chrome --web-port 8081
```

### Building for Production

```bash
# Landing page
cd landing_page
flutter build web --release --web-renderer canvaskit

# Admin dashboard
cd admin_dashboard
flutter build web --release --web-renderer canvaskit
```

## Design System

Both applications use the shared design system defined in:
- `../assets/brand/` - Brand assets, logos, icons
- `../specs/DESIGN.md` - Design specification
- Stitch project for component library

## Deployment

### Landing Page
- Static export to `build/web/`
- Deploy to Firebase Hosting, Vercel, or Netlify
- Custom domain: `daftari-pos.com`

### Admin Dashboard
- Static export to `build/web/`
- Deploy behind authentication (Firebase Auth, Auth0)
- Subdomain: `admin.daftari-pos.com`

## Shared Components

Common UI components are shared with the desktop app via:
- `../lib/core/widgets/` - Core widgets (SectionCard, AnimatedCounter, ValidatedField)
- `../lib/core/theme/` - Theme extensions, typography
- `../lib/features/` - Feature modules (adapted for web)

## License

Proprietary - Daftari POS System