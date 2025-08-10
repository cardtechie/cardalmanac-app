# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Docker-based Development (Primary)

-   `make up` - Start development environment with Docker Compose
-   `make upd` - Start development environment in detached mode
-   `make down` - Stop Docker containers
-   `make clean-docker` - Clean up Docker system (containers, images, volumes)
-   `make test` - Run tests in Docker environment
-   `make test-local` - Run tests with local Docker compose override
-   `make github-build` - Full CI pipeline (down, clean, up, test)

### Local Development Setup

1. Add GitHub Personal Access Token to `.env` as `COMPOSER_TOKEN`
2. Run `make up`
3. Access https://cardalmanac.dev:8543/ (type `thisisunsafe` for cert warnings)

### Package Management & Build

-   `composer lint` - Run PHP parallel linter
-   `npm run dev` - Development build with Laravel Mix
-   `npm run watch` - Watch files for changes
-   `npm run hot` - Hot module replacement
-   `npm run prod` - Production build
-   `npm run check` - Check code formatting with Prettier
-   `npm run format` - Format code with Prettier
-   `npm run pretest` - Run formatting check before tests
-   `npm test` - Run linting (includes PHP linting)

## High-Level Architecture

### Core Application Structure

**Card Almanac** is a Laravel-based trading card information platform that integrates with an external Trading Card API. The application serves as a digital almanac providing comprehensive card set data, checklists, and collection tools.

### Key Architectural Patterns

#### 1. External API Integration

-   **Trading Card API SDK**: Custom PHP SDK (`cardtechie/tradingcardapi-sdk-php`) handles all external API communication
-   **Configuration**: API credentials and settings in `config/tradingcardapi.php`
-   **Helper Function**: Global `tradingcardapi()` helper provides easy SDK access throughout the app
-   **Caching**: API responses are cached to improve performance

#### 2. Multi-Frontend Architecture

-   **Laravel Blade**: Server-side rendered pages for marketing and static content
-   **Vue.js 3 Components**: Interactive elements (SetChecklist, NavDrawer, MailingListForm)
-   **Hybrid Approach**: Vue components embedded in Blade templates for enhanced UX

#### 3. Content Management System

-   **Blog Platform**: Laravel CommonMark Blog package for content marketing
-   **Markdown Content**: Blog posts stored in `resources/content/blog/`
-   **Frontmatter Support**: Blog posts use YAML frontmatter for metadata
-   **Template System**: Customizable blog templates in `resources/views/content/blog/`

#### 4. Data Models & Relationships

The app works with these key entities from the Trading Card API:

-   **Set**: Trading card sets with metadata (name, release date, manufacturer)
-   **Genre**: Card categories (sports, gaming, entertainment)
-   **Card**: Individual cards within sets
-   **Checklist**: Organized card listings within sets
-   **Manufacturer/Brand/Year**: Set classification data

### Directory Structure Patterns

#### Controllers (`app/Http/Controllers/`)

-   **SetController**: Primary controller for card set operations (list, show, checklist, subsets)
-   **SetGenreController**: Handles genre-based set browsing
-   **IndexController**: Homepage functionality
-   **AboutController**: Static about page
-   **AppController**: Main application dashboard

#### Vue.js Frontend (`resources/js/`)

-   **components/**: Reusable Vue components
-   **api/**: JavaScript API clients for external services
-   **app.js**: Main application entry point with Vue 3 setup

#### API Integration (`resources/js/api/`)

-   **cards/set.api.js**: Set-related API operations
-   **send-in-blue/**: Email marketing API integration

#### Templates & Views

-   **Marketing Templates**: `resources/views/layouts/marketing/`
-   **Application Views**: `resources/views/app/`
-   **Blade Components**: `resources/views/components/`
-   **Partials**: `resources/views/partials/` (analytics, navigation, footer)

### Build & Asset Management

-   **Laravel Mix**: Webpack wrapper for asset compilation
-   **SCSS Processing**: Modern `@use` imports (Dart Sass 3.0+ compatible)
-   **CSS Framework**: Bootstrap 5.1.3 + Tailwind CSS 3.0.23 hybrid approach
-   **Vue 3 Support**: Single File Components with .vue extension
-   **Font Awesome**: Icon system with webfont copying

### Custom Helper Functions (`helpers/helpers.php`)

-   **getVersion()**: Returns git branch in development or version in production
-   **renderTitle()**: Consistent page title formatting across the application

### Navigation & Breadcrumbs

-   **Laravel Breadcrumbs**: Hierarchical navigation using `routes/breadcrumbs.php`
-   **Route Structure**: Clean URLs with optional slugs (e.g., `/sets/{id}/{name?}`)
-   **SEO-Friendly**: Slugified names in URLs for better search indexing

### Key Integration Points

-   **Trading Card API**: All card data comes from external API via custom SDK
-   **Blog System**: Content marketing platform with markdown-based posts
-   **Docker Environment**: Containerized development with compose configuration
-   **Mixed Asset Pipeline**: Combines traditional Laravel assets with Vue.js SPA components

### Important Configuration Files

-   **Blog Settings**: `config/blog.php` - Blog functionality and frontmatter defaults
-   **API Configuration**: `config/tradingcardapi.php` - External API connection settings
-   **Asset Compilation**: `webpack.mix.js` - Build pipeline for JS, CSS, and fonts
-   **Docker Setup**: `docker-compose.yml` and `makefile` for containerized development

### Testing & Quality

-   **PHP Testing**: PHPUnit with basic feature and unit tests
-   **JavaScript Quality**: Prettier for code formatting
-   **PHP Linting**: Parallel linting for syntax checking
-   **Docker Testing**: Isolated test environment with dedicated compose file
