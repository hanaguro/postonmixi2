SHELL := /bin/sh

APP_NAME := mixi2post
CMD_PATH := ./cmd/mixi2post
BIN_DIR := $(HOME)/bin
BIN_PATH := $(BIN_DIR)/$(APP_NAME)

.PHONY: help build run install fmt vet tidy

help:
	@echo "Available targets:"
	@echo "  make build    - build $(APP_NAME)"
	@echo "  make run      - run $(APP_NAME)"
	@echo "  make install  - install $(APP_NAME) to $$GOBIN or ~/go/bin"
	@echo "  make fmt      - run go fmt"
	@echo "  make vet      - run go vet"
	@echo "  make tidy     - run go mod tidy"
	@echo "  make clean    - remove build artifacts"

build:
	go mod tidy
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_PATH) $(CMD_PATH)

run:
	go run $(CMD_PATH)

install:
	go install $(CMD_PATH)

fmt:
	go fmt ./...

vet:
	go vet ./...

tidy:
	go mod tidy

