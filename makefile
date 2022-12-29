up:
	docker-compose pull
	docker-compose build
	docker-compose up

upd:
	docker-compose pull
	docker-compose build
	docker-compose up -d

down:
	docker-compose down

clean-docker:
	docker system prune -af --volumes

test:
	docker-compose -f .docker/tests.docker-compose.yaml run caapp npm test

test-local:
	docker-compose -f .docker/tests.docker-compose.yaml -f .docker/local.tests.docker-compose.yaml run caapp npm test

github-build: down clean-docker upd test
