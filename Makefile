SHELL := /bin/sh

APP_NAME := mixi2post
APP_DELETE_NAME := mixi2deletepost
CMD_PATH := ./cmd/mixi2post
CMD_DELETE_PATH := ./cmd/mixi2deletepost
BIN_DIR := $(HOME)/bin
BIN_PATH := $(BIN_DIR)/$(APP_NAME)
BIN_DELETE_PATH := $(BIN_DIR)/$(APP_DELETE_NAME)

.PHONY: help build run install fmt vet tidy

help:
	@echo "Available targets:"
	@echo "  make build    - build $(APP_NAME) and $(APP_DELETE_NAME)"
	@echo "  make fmt      - run go fmt"
	@echo "  make vet      - run go vet"
	@echo "  make tidy     - run go mod tidy"
	@echo "  make clean    - remove build artifacts"

build:
	go mod tidy
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_PATH) $(CMD_PATH)
	go build -o $(BIN_DELETE_PATH) $(CMD_DELETE_PATH)

fmt:
	go fmt ./...

vet:
	go vet ./...

tidy:
	go mod tidy

