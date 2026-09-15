FLUTTER ?= $(HOME)/.local/share/flutter/bin/flutter
DART ?= $(HOME)/.local/share/flutter/bin/dart
DOCKER_COMPOSE ?= docker-compose

.PHONY: check flutter-format flutter-analyze flutter-test flutter-web flutter-web-real api-test api-vet api-sqlc-vet api-run api-run-local local-setup local-e2e docker-up docker-down

check: flutter-format flutter-analyze flutter-test api-sqlc-vet api-test api-vet

flutter-format:
	cd revocred_flutter && $(DART) format --output=none --set-exit-if-changed lib test

flutter-analyze:
	cd revocred_flutter && $(FLUTTER) analyze

flutter-test:
	cd revocred_flutter && $(FLUTTER) test

flutter-web:
	cd revocred_flutter && $(FLUTTER) run -d web-server --web-hostname 0.0.0.0 --web-port 8081 --dart-define=REVOCRED_USE_MOCKS=true

flutter-web-real:
	@test -f .env.local || (echo '.env.local is missing; run make local-setup' && exit 1)
	cd revocred_flutter && $(FLUTTER) run -d web-server --web-hostname 0.0.0.0 --web-port 8083 --dart-define-from-file=../.env.local

api-test:
	cd revocred-api && go test ./...

api-vet:
	cd revocred-api && go vet ./...

api-sqlc-vet:
	$(MAKE) -C revocred-api sqlc-vet

docker-up:
	$(DOCKER_COMPOSE) up --build -d frontend

docker-down:
	$(DOCKER_COMPOSE) down

api-run:
	@test -f revocred-api/.env || (echo 'revocred-api/.env is missing' && exit 1)
	set -a && . revocred-api/.env && set +a && $(MAKE) -C revocred-api run

api-run-local:
	@test -f revocred-api/.env.local || (echo 'revocred-api/.env.local is missing; run make local-setup' && exit 1)
	set -a && . revocred-api/.env.local && set +a && $(MAKE) -C revocred-api run

local-setup:
	@supabase start >/dev/null
	python3 scripts/configure_local.py
	set -a && . revocred-api/.env.local && set +a && $(MAKE) -C revocred-api migrate-up

local-e2e:
	@curl -fsS http://127.0.0.1:8082/healthz >/dev/null || (echo 'local API is not running; start make api-run-local in another terminal' && exit 1)
	python3 scripts/local_e2e.py
