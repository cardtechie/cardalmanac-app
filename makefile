load-env:
	@if [ -f .env ]; then \
		echo "Loading environment variables from .env"; \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		echo "Loading environment variables from .env.local"; \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	else \
		echo "Warning: No .env or .env.local file found"; \
	fi

# COMPOSER_TOKEN is no longer passed with --build-arg: `docker history` renders
# ARG values in plaintext, so an ARG publishes the credential in the image's
# layer metadata. docker-compose.yml declares it as a build secret sourced from
# the COMPOSER_TOKEN environment variable, which the exports below provide.
up:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose pull && \
	docker compose build && \
	docker compose up

upd:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose pull && \
	docker compose build && \
	docker compose up -d

up-full:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml pull && \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml build && \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml up

upd-full:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml pull && \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml build && \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml up -d

down:
	docker compose down

down-full:
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml down

clean-docker:
	docker system prune -af --volumes

test:
	docker compose -f .docker/tests.docker-compose.yaml run caapp npm test

test-local:
	docker compose -f .docker/tests.docker-compose.yaml -f .docker/local.tests.docker-compose.yaml run caapp npm test

github-build: down clean-docker upd test

# =============================================================================
# Release Management Commands
# =============================================================================

# Version management
version:
	@./build/version.sh current

version-preview:
	@echo "Current version: $$(./build/version.sh current)"
	@echo "Next version (for branch): $$(./build/version.sh next)"
	@echo "Next major: $$(./build/version.sh next-major)"
	@echo "Next minor: $$(./build/version.sh next-minor)"  
	@echo "Next patch: $$(./build/version.sh next-patch)"

version-next:
	@./build/version.sh next

version-major:
	@./build/version.sh next-major

version-minor:
	@./build/version.sh next-minor

version-patch:
	@./build/version.sh next-patch

# Changelog management
# collate-changelog.sh folds changelog.d/ fragments into "## [Unreleased]"
# before update-changelog.sh runs; it is a clean no-op with no fragments.
changelog-preview:
	@./build/collate-changelog.sh --preview
	@./build/update-changelog.sh preview

changelog-update:
	@./build/collate-changelog.sh
	@./build/update-changelog.sh update

# Legacy manual path: for entries not tied to a PR. Routine per-PR entries go to
# changelog.d/<issue>-<type>.md instead (see changelog.d/README.md).
changelog-add:
	@read -p "Enter changelog entry: " entry; \
	read -p "Enter type (Added/Changed/Fixed/Security/etc): " type; \
	./build/update-changelog.sh add-unreleased "$$entry" "$$type"

changelog-finalize:
	@./build/update-changelog.sh finalize

# Release notes generation  
release-notes:
	@./build/generate-release-notes.sh

release-notes-preview:
	@echo "=== RELEASE NOTES PREVIEW ==="
	@echo "Version: $$(./build/version.sh current)"
	@echo ""
	@echo "# Release $$(./build/version.sh current)"
	@echo ""
	@echo "*Preview mode - would generate full release notes here*"
	@echo ""
	@echo "## What's Changed"
	@echo "- See git log for recent changes"
	@echo ""
	@echo "## Docker Images"
	@echo "- picklewagon/cardalmanac-app:$$(./build/version.sh current)"
	@echo "- picklewagon/cardalmanac-app:latest"

release-notes-github:
	@./build/generate-release-notes.sh --format github

release-notes-text:
	@./build/generate-release-notes.sh --format text

# Combined release workflow
release-prepare:
	@echo "Preparing release..."
	@./build/collate-changelog.sh
	@./build/update-changelog.sh finalize
	@./build/generate-release-notes.sh > RELEASE_NOTES.md
	@echo "Release prepared! Review CHANGELOG.md and RELEASE_NOTES.md"

release-preview:
	@echo "=== VERSION PREVIEW ==="
	@make version-preview
	@echo ""
	@echo "=== CHANGELOG PREVIEW ==="
	@./build/update-changelog.sh preview
	@echo ""
	@echo "=== RELEASE NOTES PREVIEW ==="
	@echo "Version: $$(./build/version.sh current)"
	@echo ""
	@echo "# Release $$(./build/version.sh current)"
	@echo ""
	@echo "*Preview mode - would generate full release notes here*"
	@echo ""
	@echo "## What's Changed"
	@echo "- See changelog above for recent changes"
	@echo ""
	@echo "## Docker Images"
	@echo "- picklewagon/cardalmanac-app:$$(./build/version.sh current)"
	@echo "- picklewagon/cardalmanac-app:latest"

# Help for release commands
release-help:
	@echo "Release Management Commands:"
	@echo ""
	@echo "Version Management:"
	@echo "  make version              Show current version"
	@echo "  make version-next         Show next appropriate version for branch"
	@echo "  make version-preview      Show all version options"
	@echo "  make version-major        Show next major version"
	@echo "  make version-minor        Show next minor version"
	@echo "  make version-patch        Show next patch version"
	@echo ""
	@echo "Changelog Management:"
	@echo "  make changelog-preview    Preview changelog update"
	@echo "  make changelog-update     Update changelog with current version"
	@echo "  make changelog-add        Add entry to unreleased section"
	@echo "  make changelog-finalize   Move unreleased to version section"
	@echo ""
	@echo "Release Notes:"
	@echo "  make release-notes        Generate release notes (markdown)"
	@echo "  make release-notes-github Generate GitHub release format"
	@echo "  make release-notes-text   Generate plain text format"
	@echo ""
	@echo "Release Workflow:"
	@echo "  make release-preview      Preview complete release"
	@echo "  make release-prepare      Prepare changelog and release notes"
