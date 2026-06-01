# Pinstoria — run `make help` for available targets

SCHEME      := Pinstoria
DEVICE      := iPhone 17
OS_VERSION  := 26.5
RUNTIME     := iOS $(OS_VERSION)
SIMULATOR_UDID_COMMAND = xcrun simctl list devices available 2>/dev/null | awk -v device='$(DEVICE)' -v runtime='$(RUNTIME)' '$$0 == "-- " runtime " --" { in_runtime = 1; next } /^-- / { in_runtime = 0 } in_runtime && index($$0, device " (") { if (match($$0, /[0-9A-F-]{36}/)) { print substr($$0, RSTART, RLENGTH); exit } }'
DESTINATION = platform=iOS Simulator,id=$$UDID
TEST_RESULTS_DIR := build/test-results

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
	@UDID=$$($(SIMULATOR_UDID_COMMAND)); \
	test -n "$$UDID" || { echo "No available $(DEVICE) simulator found for $(RUNTIME)." >&2; exit 1; }; \
	xcodebuild build -scheme $(SCHEME) -destination "$(DESTINATION)" -quiet

.PHONY: test
test: ## Run all tests (unit + UI)
	@mkdir -p "$(TEST_RESULTS_DIR)"
	@rm -rf "$(TEST_RESULTS_DIR)/all-tests.xcresult"
	@UDID=$$($(SIMULATOR_UDID_COMMAND)); \
	test -n "$$UDID" || { echo "No available $(DEVICE) simulator found for $(RUNTIME)." >&2; exit 1; }; \
	if command -v xcbeautify >/dev/null 2>&1; then \
		bash -o pipefail -c "xcodebuild test -scheme '$(SCHEME)' -destination \"$(DESTINATION)\" -resultBundlePath '$(TEST_RESULTS_DIR)/all-tests.xcresult' | xcbeautify"; \
	else \
		xcodebuild test -scheme $(SCHEME) -destination "$(DESTINATION)" -resultBundlePath '$(TEST_RESULTS_DIR)/all-tests.xcresult'; \
	fi

.PHONY: test-unit
test-unit: ## Run unit tests only (no UI tests)
	@mkdir -p "$(TEST_RESULTS_DIR)"
	@rm -rf "$(TEST_RESULTS_DIR)/unit-tests.xcresult"
	@UDID=$$($(SIMULATOR_UDID_COMMAND)); \
	test -n "$$UDID" || { echo "No available $(DEVICE) simulator found for $(RUNTIME)." >&2; exit 1; }; \
	if command -v xcbeautify >/dev/null 2>&1; then \
		bash -o pipefail -c "xcodebuild test -scheme '$(SCHEME)' -destination \"$(DESTINATION)\" -only-testing CameraAppTests -resultBundlePath '$(TEST_RESULTS_DIR)/unit-tests.xcresult' | xcbeautify"; \
	else \
		xcodebuild test -scheme $(SCHEME) -destination "$(DESTINATION)" -only-testing CameraAppTests -resultBundlePath '$(TEST_RESULTS_DIR)/unit-tests.xcresult'; \
	fi

.PHONY: run
run: ## Build and run the app in the simulator ($(DEVICE), $(RUNTIME))
	@UDID=$$($(SIMULATOR_UDID_COMMAND)); \
	test -n "$$UDID" || { echo "No available $(DEVICE) simulator found for $(RUNTIME)." >&2; exit 1; }; \
	echo "Using $(DEVICE) ($(RUNTIME), $$UDID)" && \
	(xcrun simctl boot "$$UDID" 2>/dev/null || true) && \
	open -a Simulator && \
	xcodebuild build -scheme $(SCHEME) -destination "$(DESTINATION)" -quiet && \
	APP=$$(xcodebuild -scheme $(SCHEME) -destination "$(DESTINATION)" -showBuildSettings 2>/dev/null | \
		awk '$$1=="BUILT_PRODUCTS_DIR" {dir=$$3} $$1=="FULL_PRODUCT_NAME" {name=$$3} END {print dir "/" name}') && \
	xcrun simctl install "$$UDID" "$$APP" && \
	xcrun simctl launch "$$UDID" com.jazzrihal.pinstoria

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf DerivedData build
	xcodebuild clean -scheme $(SCHEME) -quiet 2>/dev/null || true

# Help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
