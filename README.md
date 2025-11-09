# Dance Registration System

A comprehensive dance competition registration system built with React, TypeScript, Redux, and Supabase.

## Features

- **Multi-step Registration Wizard**: Step-by-step form for dance competition registration
- **Event Selection**: Choose from available dance events
- **Partnership Management**: Register leader and follower information
- **Flexible Competition Configuration**: Support for different age divisions, skill levels, and dance categories
- **Validation**: Age and level restrictions, partnership uniqueness checks
- **Supabase Integration**: Real-time database with authentication and RLS policies
- **Responsive Design**: Built with React-Bootstrap for mobile-friendly interface

## Tech Stack

- **Frontend**: React 18 with TypeScript
- **State Management**: Redux Toolkit
- **UI Library**: React-Bootstrap
- **Backend**: Supabase (PostgreSQL with real-time features)
- **Styling**: Bootstrap 5

## Database Schema

The system uses a flexible database schema that supports:

- **Organizations**: Ballroom, UCWDC, ACDA, etc.
- **Events**: Configurable dance competitions
- **Event Configurations**: Custom age divisions, skill levels, and dance categories per event
- **Dancers & Partnerships**: Registration management
- **Heats & Payments**: Future features for competition management

## Getting Started

### Prerequisites

- Node.js 16+
- npm or yarn
- Supabase account

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd dance-registration
```

2. Install dependencies:
```bash
npm install
```

3. Set up Supabase:
   - Create a new Supabase project
   - Run the SQL schema from `database-schema.sql`
   - Copy your project URL and anon key

4. Create environment variables:
```bash
cp .env.example .env
# Edit .env with your Supabase credentials
```

5. Start the development server:
```bash
npm start
```

## Project Structure

```
src/
├── components/           # React components
│   ├── EventSelection.tsx
│   ├── PartnershipForm.tsx
│   ├── DivisionLevelSelection.tsx
│   ├── ReviewSubmit.tsx
│   └── RegistrationWizard.tsx
├── features/            # Redux slices
│   └── registration/
│       └── registrationSlice.ts
├── types/               # TypeScript type definitions
│   └── index.ts
├── utils/               # Utility functions
│   └── supabase.ts
├── store.ts            # Redux store configuration
└── App.tsx             # Main app component
```

## Database Schema Overview

### Core Tables
- `organizations` - Dance organizations (Ballroom, UCWDC, etc.)
- `events` - Individual dance competitions
- `event_configurations` - Event-specific settings
- `dancers` - Registered dancers
- `partnerships` - Leader/follower pairs
- `registrations` - Competition entries

### Future Features
- `heats` - Competition heat assignments
- `heat_entries` - Dancer placements in heats
- `payments` - Payment processing

## Key Features Implemented

### Registration Flow
1. **Event Selection**: Browse and select from available events
2. **Partnership Details**: Enter leader and follower information
3. **Division & Level Selection**: Choose age divisions, skill levels, and dances
4. **Review & Submit**: Confirm registration and submit to database

### Validation Rules
- Age division restrictions (adjacent divisions only)
- Skill level limits (up to 2 levels)
- Partnership uniqueness per event
- Professional/amateur status handling

### Security
- Row Level Security (RLS) policies
- User authentication and authorization
- Role-based access control

## Future Enhancements

- **Admin Dashboard**: Event configuration and management
- **Heating System**: Automatic heat assignment algorithms
- **Heat Sheet Lookup**: Dancer heat search functionality
- **Payment Integration**: Stripe integration for online payments
- **Email Notifications**: Registration confirmations and updates
- **Results Management**: Competition scoring and results

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License.
