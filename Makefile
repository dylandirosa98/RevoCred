FLUTTER ?= $(HOME)/.local/share/flutter/bin/flutter
DART ?= $(HOME)/.local/share/flutter/bin/dart
DOCKER_COMPOSE ?= docker-compose
IOS_CONFIG ?= .env.ios.json
IOS_BUILD_NUMBER ?=
IOS_EXPORT_OPTIONS ?= .local/ios/ExportOptions.plist

.PHONY: check flutter-format flutter-analyze flutter-test flutter-web flutter-web-real api-test api-vet api-sqlc-vet api-run api-run-local local-setup local-e2e docker-up docker-down database-test release-check security-check verify-local local-preview local-stop browser-smoke setup-opencode-go

check: flutter-format flutter-analyze flutter-test api-sqlc-vet api-test api-vet

.PHONY: database-test
database-test:
	$(MAKE) -C revocred-api tools
	python3 scripts/test_database.py

.PHONY: release-check security-check
release-check:
	python3 scripts/check_release_config.py

security-check:
	cd revocred-api && go run golang.org/x/vuln/cmd/govulncheck@v1.1.4 ./...

.PHONY: ios-release-check ios-release
ios-release-check:
	python3 scripts/ios_release.py --check --config "$(IOS_CONFIG)"

# Builds locally on macOS; never uploads or submits for review.
ios-release: check
	FLUTTER="$(FLUTTER)" python3 scripts/ios_release.py --config "$(IOS_CONFIG)" --build-number "$(IOS_BUILD_NUMBER)" --export-options "$(IOS_EXPORT_OPTIONS)"

.PHONY: verify-local
verify-local:
	python3 scripts/verify_local_stack.py

.PHONY: local-preview local-stop share-preview share-stop share-report
local-preview:
	python3 scripts/local_preview.py

local-stop:
	python3 scripts/local_preview.py stop

# Public quick-tunnel preview. Writes only the gitignored .env.share files so
# the loopback local-preview/verify-local gates keep working.
share-report:
	python3 scripts/share_tunnel.py

share-preview:
	python3 scripts/share_tunnel.py --apply
	python3 scripts/share_preview.py

share-stop:
	python3 scripts/share_preview.py stop

# Local-only, explicit refresh of public card descriptions. The running API also
# checks every 24 hours and retains the last-known-good DB snapshot on failure.
.PHONY: card-data-refresh card-data-status
card-data-refresh:
	@test -f revocred-api/.env.local || (echo 'Run make local-setup first' && exit 1)
	set -a && . revocred-api/.env.local && set +a && cd revocred-api && go run ./cmd/carddata --refresh

card-data-status:
	@test -f revocred-api/.env.local || (echo 'Run make local-setup first' && exit 1)
	set -a && . revocred-api/.env.local && set +a && cd revocred-api && go run ./cmd/carddata

.PHONY: setup-opencode-go
setup-opencode-go:
	@test -t 0 || { echo 'Run this in your own terminal: ./scripts/enter-opencode-go-key.sh'; exit 1; }
	./scripts/enter-opencode-go-key.sh

# Real-browser smoke needs `python3 -m pip install -r scripts/requirements-browser.txt`
# plus a Chromium binary (CHROMIUM_PATH defaults to /snap/bin/chromium).
.PHONY: browser-smoke
browser-smoke:
	@curl -fsS http://127.0.0.1:8082/readyz >/dev/null || (echo 'start make local-preview first' && exit 1)
	@curl -fsS http://127.0.0.1:54324/ >/dev/null || (echo 'local Supabase Mailpit is not running' && exit 1)
	python3 scripts/browser_smoke.py

flutter-format:
	cd revocred_flutter && $(DART) format --output=none --set-exit-if-changed lib test tool

flutter-analyze:
	cd revocred_flutter && $(FLUTTER) analyze

flutter-test:
	cd revocred_flutter && $(FLUTTER) test

flutter-web:
	cd revocred_flutter && $(FLUTTER) run -d web-server --web-hostname 0.0.0.0 --web-port 8081 --dart-define=REVOCRED_USE_MOCKS=true

flutter-web-real:
	@test -f .env.local || (echo '.env.local is missing; run make local-setup' && exit 1)
	cd revocred_flutter && $(FLUTTER) run --release -d web-server --web-hostname 0.0.0.0 --web-port 8083 --dart-define-from-file=../.env.local

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
