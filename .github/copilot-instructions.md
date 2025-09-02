---
applyTo: '**'
---

# Copilot instructions (English — concise)

Purpose: provide short, actionable guidance so Copilot suggestions match project conventions.

## Common Development Commands

### Development Server
- `bin/dev` - Start development server (Rails, Sidekiq, Tailwind CSS watcher)
- `bin/rails server` - Start Rails server only
- `bin/rails console` - Open Rails console

### Testing
- `bin/rails test` - Run all tests
- `bin/rails test:db` - Run tests with database reset
- `bin/rails test:system` - Run system tests only (use sparingly - they take longer)
- `bin/rails test test/models/account_test.rb` - Run specific test file
- `bin/rails test test/models/account_test.rb:42` - Run specific test at line

### Linting & Formatting
- `bin/rubocop` - Run Ruby linter
- `npm run lint` - Check JavaScript/TypeScript code
- `npm run lint:fix` - Fix JavaScript/TypeScript issues
- `npm run format` - Format JavaScript/TypeScript code
- `bin/brakeman` - Run security analysis

### Database
- `bin/rails db:prepare` - Create and migrate database
- `bin/rails db:migrate` - Run pending migrations
- `bin/rails db:rollback` - Rollback last migration
- `bin/rails db:seed` - Load seed data

### Setup
- `bin/setup` - Initial project setup (installs dependencies, prepares database)

## Pre-PR workflow (run locally before opening PR)
- Tests: bin/rails test (all), bin/rails test:system (when applicable)
- Linters: bin/rubocop -f github -a; bundle exec erb_lint ./app/**/*.erb -a
- Security: bin/brakeman --no-pager

## High-Level Architecture

### Application Modes
The app runs in two modes:
- **Managed** (Rails.application.config.app_mode = "managed")
- **Self-hosted** (Rails.application.config.app_mode = "self_hosted")

### Core Domain Model
The application is built around financial data management with these key relationships:
- **User** → has many **Accounts** → has many **Transactions**
- **Account** types: checking, savings, credit cards, investments, crypto, loans, properties
- **Transaction** → belongs to **Category**, can have **Tags** and **Rules**
- **Investment accounts** → have **Holdings** → track **Securities** via **Trades**

### API Architecture
The application provides both internal and external APIs:
- Internal API: Controllers serve JSON via Turbo for SPA-like interactions
- External API: `/api/v1/` namespace with Doorkeeper OAuth and API key authentication
- API responses use Jbuilder templates for JSON rendering.
- Rate limiting via Rack::Attack with configurable limits per API key

### Sync & Import System
Two primary data ingestion methods:
1. **Plaid Integration**: Real-time bank account syncing
   - `PlaidItem` manages connections
   - `Sync` tracks sync operations
   - Background jobs handle data updates
2. **CSV Import**: Manual data import with mapping
   - `Import` manages import sessions
   - Supports transaction and balance imports
   - Custom field mapping with transformation rules

### Background Processing
Sidekiq handles asynchronous tasks:
- Account syncing (`SyncJob`)
- Import processing (`ImportJob`)
- AI chat responses (`AssistantResponseJob`)
- Scheduled maintenance via sidekiq-cron

### Frontend Architecture
- **Hotwire Stack**: Turbo + Stimulus for reactive UI without heavy JavaScript
- **ViewComponents**: Reusable UI components in `app/components/`
- **Stimulus Controllers**: Handle interactivity, organized alongside components
- **Charts**: D3.js for financial visualizations (time series, donut, sankey)
- **Styling**: Tailwind CSS v4.x with custom design system
  - Design system defined in `app/assets/tailwind/maybe-design-system.css`
  - Always use functional tokens (e.g., `text-primary` not `text-white`)
  - Prefer semantic HTML elements over JS components
  - Use `icon` helper for icons, never `lucide_icon` directly

### Multi-Currency Support
- All monetary values stored in base currency (user's primary currency)
- `Money` objects handle currency conversion and formatting
- Historical exchange rates for accurate reporting

### Security & Authentication
- Session-based auth for web users
- API authentication via:
  - OAuth2 (Doorkeeper) for third-party apps
  - API keys with JWT tokens for direct API access
- Scoped permissions system for API access
- Strong parameters and CSRF protection throughout

## Key rules
- Project modes: "managed" or "self_hosted".
- Domain: User → Accounts → Transactions. Keep business logic in models, controllers thin.

Authentication & context
- Use Current.user and Current.family (never current_user / current_family).

Testing conventions
- Use Minitest + fixtures (no RSpec, no FactoryBot).
- Use mocha for mocks where needed; VCR for external API tests.

Frontend conventions
- Hotwire-first: Turbo + Stimulus.
- Prefer semantic HTML, Turbo Frames, server-side formatting.
- Use the helper icon for icons (do not use lucide_icon directly).
- Use Tailwind design tokens (text-primary, bg-container, etc.).

Backend & architecture
- Skinny controllers, fat models.
- Prefer built-in Rails patterns; add dependencies only with strong justification.
- Sidekiq for background jobs (e.g., SyncJob, ImportJob, AssistantResponseJob).

API & security
- External API under /api/v1 with Doorkeeper / API keys; respect CSRF and strong params.
- Follow rate limits and auth strategies already in project.

Stimulus & components
- Keep controllers small (< 7 targets); pass data via data-*-value.
- Prefer ViewComponents for reusable or complex UI.

## Component Architecture

### ViewComponent vs Partials Decision Making

**Use ViewComponents when:**
- Element has complex logic or styling patterns
- Element will be reused across multiple views/contexts
- Element needs structured styling with variants/sizes
- Element requires interactive behavior or Stimulus controllers
- Element has configurable slots or complex APIs
- Element needs accessibility features or ARIA support

**Use Partials when:**
- Element is primarily static HTML with minimal logic
- Element is used in only one or few specific contexts
- Element is simple template content
- Element doesn't need variants, sizes, or complex configuration
- Element is more about content organization than reusable functionality

**Component Guidelines:**
- Prefer components over partials when available
- Keep domain logic OUT of view templates
- Logic belongs in component files, not template files

### Stimulus Controller Guidelines

**Declarative Actions (Required):**
```erb
<!-- GOOD: Declarative - HTML declares what happens -->
<div data-controller="toggle">
  <button data-action="click->toggle#toggle" data-toggle-target="button">Show</button>
  <div data-toggle-target="content" class="hidden">Hello World!</div>
</div>
```

**Controller Best Practices:**
- Keep controllers lightweight and simple (< 7 targets)
- Use private methods and expose clear public API
- Single responsibility or highly related responsibilities
- Component controllers stay in component directory, global controllers in `app/javascript/controllers/`
- Pass data via `data-*-value` attributes, not inline JavaScript

## Testing Philosophy

### General Testing Rules
- **ALWAYS use Minitest + fixtures + Mocha** (NEVER RSpec or FactoryBot)
- Keep fixtures minimal (2-3 per model for base cases)
- Create edge cases on-the-fly within test context
- Use Rails helpers for large fixture creation needs

### Test Quality Guidelines
- **Write minimal, effective tests** - system tests sparingly
- **Only test critical and important code paths**
- **Test boundaries correctly:**
  - Commands: test they were called with correct params
  - Queries: test output
  - Don't test implementation details of other classes

### Testing Examples

```ruby
# GOOD - Testing critical domain business logic
test "syncs balances" do
  Holding::Syncer.any_instance.expects(:sync_holdings).returns([]).once
  assert_difference "@account.balances.count", 2 do
    Balance::Syncer.new(@account, strategy: :forward).sync_balances
  end
end

# BAD - Testing ActiveRecord functionality
test "saves balance" do 
  balance_record = Balance.new(balance: 100, currency: "USD")
  assert balance_record.save
end
```

### Stubs and Mocks
- Use `mocha` gem
- Prefer `OpenStruct` for mock instances
- Only mock what's necessary

## Performance Considerations
- Database queries optimized with proper indexes
- N+1 queries prevented via includes/joins
- Background jobs for heavy operations
- Caching strategies for expensive calculations
- Turbo Frames for partial page updates

## Development Workflow
- Feature branches merged to `main`
- Docker support for consistent environments
- Environment variables via `.env` files
- Lookbook for component development (`/design-system`)
- Letter Opener for email preview in development

## Project Conventions

### Convention 1: Minimize Dependencies
- Push Rails to its limits before adding new dependencies
- Strong technical/business reason required for new dependencies
- Favor old and reliable over new and flashy

### Convention 2: Skinny Controllers, Fat Models
- Business logic in `app/models/` folder, avoid `app/services/`
- Use Rails concerns and POROs for organization
- Models should answer questions about themselves: `account.balance_series` not `AccountSeries.new(account).call`

### Convention 3: Hotwire-First Frontend
- **Native HTML preferred over JS components**
  - Use `<dialog>` for modals, `<details><summary>` for disclosures
  - **Leverage Turbo frames** for page sections over client-side solutions
  - **Query params for state** over localStorage/sessions
  - **Server-side formatting** for currencies, numbers, dates
  - **Always use `icon` helper** in `application_helper.rb`, NEVER `lucide_icon` directly

### Convention 4: Optimize for Simplicity
- Prioritize good OOP domain design over performance
- Focus performance only on critical/global areas (avoid N+1 queries, mindful of global layouts)

### Convention 5: Database vs ActiveRecord Validations
- Simple validations (null checks, unique indexes) in DB
- ActiveRecord validations for convenience in forms (prefer client-side when possible)
- Complex validations and business logic in ActiveRecord

## TailwindCSS Design System

### Design System Rules
- **Always reference `app/assets/tailwind/maybe-design-system.css`** for primitives and tokens
- **Use functional tokens** defined in design system:
  - `text-primary` instead of `text-white`
  - `bg-container` instead of `bg-white`
  - `border border-secondary` instead of `border border-gray-200`
- **NEVER create new styles** in design system files without permission
- **Always generate semantic HTML**

Disallowed suggestions / behaviors
- Do NOT propose running system commands in PRs (rails server, rails credentials, touching tmp files, auto-running migrations).
- Avoid adding new global styles to design system without permission.
- Do not produce offensive, dangerous, or non-technical content.

Style for suggestions
- Make changes atomic and testable; explain impact briefly.
- Keep suggestions concise and aligned with existing code.
- Respect existing tests; add tests when changing critical logic.

Notes from repository config
- If .gemini/config.yaml disables automated code_review, still provide clear summaries and fix suggestions in PRs.
