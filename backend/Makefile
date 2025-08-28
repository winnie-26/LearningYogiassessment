SHELL := /bin/sh

APP := server
PKG := ./cmd/app

.PHONY: tidy build run test lint vet docker

tidy:
	go mod tidy

build:
	go build -o $(APP) $(PKG)

run:
	go run $(PKG)

test:
	go test ./...

lint:
	test -z "$(gofmt -l .)" || (gofmt -d . && exit 1)

vet:
	go vet ./...

docker:
	docker build -t secure-messaging-backend:local .
