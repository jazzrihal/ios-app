# CameraApp — run `make help` for available targets

SCHEME      := CameraApp
DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
RUN_DEVICE  := iPhone SE (3rd generation)

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

.PHONY: run
run: ## Build and run the app in the simulator (iPhone SE 3rd gen)
	@UDID=$$(xcrun simctl list devices available | grep '$(RUN_DEVICE)' | tail -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}') && \
	echo "Using $(RUN_DEVICE) ($$UDID)" && \
	(xcrun simctl boot "$$UDID" 2>/dev/null || true) && \
	open -a Simulator && \
	xcodebuild build -scheme $(SCHEME) -destination "id=$$UDID" -quiet && \
	APP=$$(xcodebuild -scheme $(SCHEME) -destination "id=$$UDID" -showBuildSettings 2>/dev/null | \
		awk '$$1=="BUILT_PRODUCTS_DIR" {dir=$$3} $$1=="FULL_PRODUCT_NAME" {name=$$3} END {print dir "/" name}') && \
	xcrun simctl install "$$UDID" "$$APP" && \
	xcrun simctl launch "$$UDID" com.cameraapp.CameraApp

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf DerivedData build
	xcodebuild clean -scheme $(SCHEME) -quiet 2>/dev/null || true

# Help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
