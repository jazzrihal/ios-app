# CameraApp — run `make help` for available targets

SCHEME      := CameraApp
DESTINATION := platform=iOS Simulator,name=iPhone 16,OS=latest

.DEFAULT_GOAL := help

# Code quality

.PHONY: lint
lint: ## Run SwiftLint (strict)
	swiftlint lint --config .swiftlint.yml --strict

.PHONY: lint-fix
lint-fix: ## Auto-correct SwiftLint violations
	swiftlint lint --config .swiftlint.yml --fix

.PHONY: format
format: ## Run SwiftFormat on the project
	swiftformat . --config .swiftformat

.PHONY: format-check
format-check: ## Check formatting without changes (for CI)
	swiftformat . --config .swiftformat --lint

.PHONY: quality
quality: format lint ## Format then lint

# Project

.PHONY: generate
generate: ## Generate Xcode project
	xcodegen generate

.PHONY: setup
setup: ## One-time setup: install tools, hooks, generate project
	brew install swiftlint swiftformat xcodegen || true
	./scripts/install-hooks.sh
	xcodegen generate

# Build & test

.PHONY: build
build: ## Build the app
	xcodebuild build -scheme $(SCHEME) -destination '$(DESTINATION)' -quiet

.PHONY: test
test: ## Run all tests
	xcodebuild test -scheme $(SCHEME) -destination '$(DESTINATION)' -quiet

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf DerivedData build
	xcodebuild clean -scheme $(SCHEME) -quiet 2>/dev/null || true

# Help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
