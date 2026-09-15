TOOLS_DIR ?= $(CURDIR)/bin
GOOSE_VERSION ?= v3.24.3
SQLC_VERSION ?= v1.29.0
GOOSE ?= $(TOOLS_DIR)/goose
SQLC ?= $(TOOLS_DIR)/sqlc
MIGRATIONS_DIR ?= migrations

.PHONY: run test vet check tools generate sqlc-generate sqlc-vet migrate-up migrate-down migrate-reset migrate-status migration

run:
	go run ./cmd/api

test:
	go test ./...

vet:
	go vet ./...

check: sqlc-vet test vet

tools: $(GOOSE) $(SQLC)

$(GOOSE):
	mkdir -p $(TOOLS_DIR)
	GOBIN=$(TOOLS_DIR) go install github.com/pressly/goose/v3/cmd/goose@$(GOOSE_VERSION)

$(SQLC):
	mkdir -p $(TOOLS_DIR)
	GOBIN=$(TOOLS_DIR) go install github.com/sqlc-dev/sqlc/cmd/sqlc@$(SQLC_VERSION)

generate: sqlc-generate

sqlc-generate: $(SQLC)
	$(SQLC) generate

sqlc-vet: $(SQLC)
	$(SQLC) vet

migrate-up: $(GOOSE)
	@test -n "$(DATABASE_URL)" || (echo "DATABASE_URL is required" && exit 1)
	$(GOOSE) -dir $(MIGRATIONS_DIR) postgres "$(DATABASE_URL)" up

migrate-down: $(GOOSE)
	@test -n "$(DATABASE_URL)" || (echo "DATABASE_URL is required" && exit 1)
	$(GOOSE) -dir $(MIGRATIONS_DIR) postgres "$(DATABASE_URL)" down

migrate-reset: $(GOOSE)
	@test -n "$(DATABASE_URL)" || (echo "DATABASE_URL is required" && exit 1)
	$(GOOSE) -dir $(MIGRATIONS_DIR) postgres "$(DATABASE_URL)" down-to 0

migrate-status: $(GOOSE)
	@test -n "$(DATABASE_URL)" || (echo "DATABASE_URL is required" && exit 1)
	$(GOOSE) -dir $(MIGRATIONS_DIR) postgres "$(DATABASE_URL)" status

migration: $(GOOSE)
	@test -n "$(NAME)" || (echo "NAME is required, for example: make migration NAME=create_strategies" && exit 1)
	$(GOOSE) -dir $(MIGRATIONS_DIR) create "$(NAME)" sql
