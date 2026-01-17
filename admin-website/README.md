# Pastee Admin Dashboard

A modern web-based admin dashboard for managing Pastee application.

## Features

- **Dashboard** - View user statistics, growth rates, and 7-day trends
- **Users Management** - Search, view, and manage user accounts
- **Version Management** - Publish and manage application versions

## Tech Stack

- React 18 + TypeScript
- Vite
- Tailwind CSS
- React Router

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Development

The development server runs at `http://localhost:3000`.

## API Endpoints

The dashboard connects to the Pastee API at `https://api.pastee-app.com`:

- `POST /auth/login` - Authentication
- `GET /admin/dashboard` - Dashboard statistics
- `GET /admin/users` - User list with pagination
- `DELETE /admin/users/:id` - Delete user
- `POST /admin/users/:id/reset-password` - Reset user password
- `GET /version/versions` - Version list
- `POST /version/versions` - Create new version
- `DELETE /version/versions/:id` - Delete version

## Access

Admin access is restricted to `admin@pastee.im`.
