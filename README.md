# Card Almanac

The definitive digital trading card almanac - comprehensive data, interactive checklists, and collection tools for trading card collectors and enthusiasts.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PHP Version](https://img.shields.io/badge/PHP-8.2%2B-blue.svg)](https://php.net)
[![Laravel](https://img.shields.io/badge/Laravel-12.0-red.svg)](https://laravel.com)

## Features

- **Comprehensive Set Database**: Complete information on trading card sets across multiple genres
- **Interactive Checklists**: Digital checklists with enhanced functionality
- **Multi-Genre Support**: Coverage of sports, gaming, entertainment, and other trading card categories
- **Real-time Data**: Integration with Trading Card API for up-to-date information
- **Responsive Design**: Optimized for desktop and mobile browsing
- **Blog Platform**: Educational content and industry insights
- **Search & Browse**: Powerful search and filtering capabilities

## Quick Start

### Prerequisites

- Docker and Docker Compose
- GitHub Personal Access Token (optional — raises the anonymous GitHub API rate limit when Composer fetches dependencies; builds succeed without one)

### Installation

1. **Clone the repository**

    ```bash
    git clone https://github.com/cardtechie/cardalmanac-app.git
    cd cardalmanac-app
    ```

2. **Environment Setup**

    ```bash
    # Copy environment file
    cp .env.example .env

    # Optional: a GitHub Personal Access Token raises the anonymous GitHub API
    # rate limit during composer install. Both Composer VCS sources are public,
    # so builds succeed without it. It is passed to the build as a BuildKit
    # secret and never written into the image.
    #
    # Only add it if you have a real token. A placeholder is worse than nothing:
    # composer authenticates with whatever it is given, and GitHub answers a
    # bogus credential with 401 where it would have answered anonymously with
    # 200. Leave this line commented out otherwise.
    # echo "COMPOSER_TOKEN=<your real github token>" >> .env

    # Add Trading Card API credentials (optional for basic browsing)
    echo "TRADINGCARDAPI_CLIENT_ID=your_client_id" >> .env
    echo "TRADINGCARDAPI_CLIENT_SECRET=your_client_secret" >> .env
    ```

3. **Start Development Environment**

    ```bash
    # Minimal setup (recommended for UI development)
    make upd

    # OR Full stack (for API integration work)
    make upd-full
    ```

4. **Access the Application**
    - Navigate to https://cardalmanac.dev:8541/
    - Type `thisisunsafe` if prompted about certificate warnings

For detailed setup options and troubleshooting, see **[docs/LOCAL-ENVIRONMENTS.md](docs/LOCAL-ENVIRONMENTS.md)**. For release and deployment information, see **[docs/RELEASE-AUTOMATION.md](docs/RELEASE-AUTOMATION.md)**.

## Development Commands

### Docker-based Development

```bash
# Start development environment
make up          # Start containers
make upd         # Start in detached mode (minimal)
make upd-full    # Start full development stack
make down        # Stop containers
make clean-docker # Clean up Docker system

# Testing
make test        # Run tests in Docker
make test-local  # Run tests with local overrides
make github-build # Full CI pipeline
```

### Package Management

```bash
# PHP
composer install    # Install PHP dependencies
composer lint       # Run PHP syntax checking

# JavaScript
npm install         # Install Node dependencies
npm run dev         # Development build
npm run watch       # Watch for changes
npm run hot         # Hot module replacement
npm run prod        # Production build
npm run check       # Check code formatting
npm run format      # Format code with Prettier
npm test           # Run all linting
```

## Technology Stack

- **Backend**: Laravel 12.0 (PHP 8.2+)
- **Frontend**: Vue.js 3.5.16 with Vuetify 3.8.7
- **CSS**: Bootstrap 5.1.3 + Tailwind CSS 3.0.23
- **Build**: Laravel Mix with Webpack
- **Database**: MySQL 8.0+
- **API Integration**: Custom Trading Card API SDK
- **Blog**: Laravel CommonMark for content management
- **Deployment**: Docker with docker-compose

## Project Structure

```
├── app/                    # Laravel application code
│   ├── Http/Controllers/   # Controllers for web routes
│   └── Providers/          # Service providers
├── resources/
│   ├── js/                 # Vue.js components and JavaScript
│   │   ├── components/     # Reusable Vue components
│   │   └── api/           # API client libraries
│   ├── views/             # Blade templates
│   └── content/blog/      # Blog posts (Markdown)
├── routes/                 # Route definitions
├── docs/                  # Project documentation
└── .docker/               # Docker configuration files
```

## API Integration

Card Almanac integrates with the Trading Card API to provide real-time data:

- **Sets**: Browse trading card sets by genre, year, and manufacturer
- **Cards**: View individual card details and checklists
- **Search**: Find specific sets and cards across the database
- **Caching**: API responses are cached for improved performance

## Contributing

We welcome contributions to Card Almanac! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes** following the existing code style
4. **Run the tests** (`make test`)
5. **Commit your changes** (`git commit -m 'Add amazing feature'`)
6. **Push to the branch** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

### Development Guidelines

- Follow PSR coding standards for PHP
- Use Prettier for JavaScript/CSS formatting
- Write tests for new features
- Update documentation as needed

### Automated Dependency Updates

This project uses [Dependabot](https://docs.github.com/en/code-security/dependabot) for automated dependency updates:

- **Weekly Updates**: Dependencies are checked every Monday at 9:00 AM (Denver time)
- **Supported Ecosystems**: PHP Composer, npm, and GitHub Actions
- **Automated PRs**: Dependabot creates pull requests for dependency updates
- **Grouped Updates**: Related dependencies (Vue.js ecosystem, build tools, etc.) are grouped together
- **Manual Review**: All dependency updates require manual review and approval

Dependabot will automatically ignore `dev-main` dependencies that should be manually managed (like the Trading Card API SDK).

## Security

If you discover a security vulnerability, please send an email to the maintainers. All security vulnerabilities will be promptly addressed.

## License

This project is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).

## Links

- **Website**: [Card Almanac](https://cardalmanac.dev)
- **Twitter**: [@cardalmanac](https://twitter.com/cardalmanac)
- **API Documentation**: [Trading Card API](https://tradingcardapi.dev)
- **TLS Certificates**: [docs/TLS-CERTIFICATES.md](docs/TLS-CERTIFICATES.md)
