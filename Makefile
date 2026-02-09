# CameraApp — Developer Commands
# Run `make help` to see available targets.

SCHEME       := CameraApp
PLATFORM     := iOS Simulator
DESTINATION  := platform=$(PLATFORM),name=iPhone 16,OS=latest

.DEFAULT_GOAL := help

# ──────────────────────────── Code Quality ───────────────────────

.PHONY: lint
lint: ## Run SwiftLint in strict mode
	swiftlint lint --config .swiftlint.yml --strict

.PHONY: lint-fix
lint-fix: ## Run SwiftLint with auto-correct
	swiftlint lint --config .swiftlint.yml --fix

.PHONY: format
format: ## Run SwiftFormat on the entire project
	swiftformat . --config .swiftformat

.PHONY: format-check
format-check: ## Check formatting without making changes (useful in CI)
	swiftformat . --config .swiftformat --lint

.PHONY: quality
quality: format lint ## Run format then lint (full code quality pass)

# ──────────────────────────── Project ────────────────────────────

.PHONY: generate
generate: ## Generate Xcode project via XcodeGen
	xcodegen generate

.PHONY: setup
setup: ## One-time setup: install tools, hooks, and generate project
	@echo "Installing tools via Homebrew..."
	brew install swiftlint swiftformat xcodegen || true
	@echo "Installing pre-commit hook..."
	./scripts/install-hooks.sh
	@echo "Generating Xcode project..."
	xcodegen generate
	@echo "✓ Setup complete!"

# ──────────────────────────── Build & Test ───────────────────────

.PHONY: build
build: ## Build the project
	xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-quiet

.PHONY: test
test: ## Run all tests
	xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-quiet

# ──────────────────────────── Cleanup ────────────────────────────

.PHONY: clean
clean: ## Remove DerivedData and build artifacts
	rm -rf DerivedData build
	xcodebuild clean -scheme $(SCHEME) -quiet 2>/dev/null || true
	@echo "✓ Clean complete"

# ──────────────────────────── Help ───────────────────────────────

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
