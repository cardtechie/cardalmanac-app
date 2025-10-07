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

up:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose pull && \
	docker compose build --build-arg COMPOSER_TOKEN=$${COMPOSER_TOKEN} && \
	docker compose up

upd:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose pull && \
	docker compose build --build-arg COMPOSER_TOKEN=$${COMPOSER_TOKEN} && \
	docker compose up -d

up-full:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml pull && \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml build --build-arg COMPOSER_TOKEN=$${COMPOSER_TOKEN} && \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml up

upd-full:
	@if [ -f .env ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env); \
	elif [ -f .env.local ]; then \
		export $$(grep -vE "^(#.*|\s*)$$" .env.local); \
	fi; \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml pull && \
	docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml build --build-arg COMPOSER_TOKEN=$${COMPOSER_TOKEN} && \
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
