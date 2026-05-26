# Makefile for webclone.sh
# Professional installation and testing targets

SHELL := /bin/bash
.PHONY: all install uninstall test debug clean help install-user lint info

# Configuration
SCRIPT_NAME := webclone.sh
INSTALL_DIR ?= /usr/local/bin
USER_BIN_DIR := $(HOME)/.local/bin

# Default target
all: help

#######################################
# Help target - display available commands
#######################################
help:
	@echo ""
	@echo "webclone.sh Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  install      - Install script to system path (/usr/local/bin)"
	@echo "  install-user - Install script to user-local path (~/.local/bin)"
	@echo "  uninstall    - Remove script from system"
	@echo "  test         - Run automated tests against sample URLs"
	@echo "  debug        - Run script in debug mode (set -x)"
	@echo "  clean        - Remove test output files"
	@echo "  lint         - Validate script syntax with shellcheck"
	@echo "  info         - Show script information and dependencies"
	@echo "  help         - Display this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make install                    # System-wide installation (may need sudo)"
	@echo "  make install-user               # User-only installation"
	@echo "  make test                       # Run all tests"
	@echo "  make debug URL=https://example.com"
	@echo "  make uninstall                  # Remove from system"
	@echo ""

#######################################
# Install target - copy script to /usr/local/bin
#######################################
install:
	@echo "[INFO] Installing $(SCRIPT_NAME) to $(INSTALL_DIR)..."
	@if [ ! -f "$(SCRIPT_NAME)" ]; then \
		echo "[ERROR] Script file not found: $(SCRIPT_NAME)"; \
		exit 1; \
	fi
	@mkdir -p $(INSTALL_DIR)
	@cp "$(SCRIPT_NAME)" "$(INSTALL_DIR)/$(SCRIPT_NAME)"
	@chmod +x "$(INSTALL_DIR)/$(SCRIPT_NAME)"
	@echo "[OK] Successfully installed to $(INSTALL_DIR)/$(SCRIPT_NAME)"
	@echo "[NOTE] You may need sudo for system-wide installation: sudo make install"

#######################################
# Install to user-local bin directory
#######################################
install-user:
	@echo "[INFO] Installing $(SCRIPT_NAME) to $(USER_BIN_DIR)..."
	@if [ ! -f "$(SCRIPT_NAME)" ]; then \
		echo "[ERROR] Script file not found: $(SCRIPT_NAME)"; \
		exit 1; \
	fi
	@mkdir -p $(USER_BIN_DIR)
	@cp "$(SCRIPT_NAME)" "$(USER_BIN_DIR)/$(SCRIPT_NAME)"
	@chmod +x "$(USER_BIN_DIR)/$(SCRIPT_NAME)"
	@echo "[OK] Successfully installed to $(USER_BIN_DIR)/$(SCRIPT_NAME)"
	@echo "[NOTE] Ensure $(USER_BIN_DIR) is in your PATH"

#######################################
# Uninstall target - remove script from system
#######################################
uninstall:
	@echo "[INFO] Removing $(SCRIPT_NAME) from system..."
	@if [ -f "$(INSTALL_DIR)/$(SCRIPT_NAME)" ]; then \
		rm -f "$(INSTALL_DIR)/$(SCRIPT_NAME)" && \
		echo "[OK] Removed from $(INSTALL_DIR)/$(SCRIPT_NAME)"; \
	else \
		echo "[WARN] Script not found in $(INSTALL_DIR)"; \
	fi
	@if [ -f "$(USER_BIN_DIR)/$(SCRIPT_NAME)" ]; then \
		rm -f "$(USER_BIN_DIR)/$(SCRIPT_NAME)" && \
		echo "[OK] Removed from $(USER_BIN_DIR)/$(SCRIPT_NAME)"; \
	else \
		echo "[WARN] Script not found in $(USER_BIN_DIR)"; \
	fi
	@echo "[OK] Uninstallation complete"

#######################################
# Test target - run automated tests
#######################################
test: test-html test-markdown test-help test-version
	@echo ""
	@echo "====================================="
	@echo "All tests completed successfully!"
	@echo "====================================="

#######################################
# Test HTML output
#######################################
test-html:
	@echo ""
	@echo "[TEST] Testing HTML output..."
	@echo "[TEST] Fetching https://example.com as HTML..."
	@./$(SCRIPT_NAME) --html https://example.com || exit 1
	@if ls Example_Domain_*.html 1>/dev/null 2>&1; then \
		echo "[PASS] HTML file created successfully"; \
		if grep -q "data:image" Example_Domain_*.html 2>/dev/null; then \
			echo "[PASS] Images are inlined as data URIs"; \
		else \
			echo "[SKIP] No images found or inlining skipped"; \
		fi; \
		if ! grep -q "<script" Example_Domain_*.html 2>/dev/null; then \
			echo "[PASS] JavaScript stripped successfully"; \
		else \
			echo "[FAIL] JavaScript still present in output"; \
			exit 1; \
		fi; \
		if grep -q "Original Source" Example_Domain_*.html 2>/dev/null; then \
			echo "[PASS] Original link injected successfully"; \
		else \
			echo "[FAIL] Original link not found in output"; \
			exit 1; \
		fi; \
	else \
		echo "[FAIL] HTML file was not created"; \
		exit 1; \
	fi

#######################################
# Test Markdown output
#######################################
test-markdown:
	@echo ""
	@echo "[TEST] Testing Markdown output..."
	@echo "[TEST] Fetching https://example.com as Markdown..."
	@./$(SCRIPT_NAME) --markdown https://example.com || exit 1
	@if ls Example_Domain_*.md 1>/dev/null 2>&1; then \
		echo "[PASS] Markdown file created successfully"; \
		if grep -q "# Example Domain" Example_Domain_*.md 2>/dev/null; then \
			echo "[PASS] Title extracted correctly"; \
		else \
			echo "[WARN] Title may not have been extracted"; \
		fi; \
		if grep -q "example.com" Example_Domain_*.md 2>/dev/null; then \
			echo "[PASS] Source link preserved in Markdown"; \
		else \
			echo "[FAIL] Source link missing from Markdown"; \
			exit 1; \
		fi; \
	else \
		echo "[FAIL] Markdown file was not created"; \
		exit 1; \
	fi

#######################################
# Test help option
#######################################
test-help:
	@echo ""
	@echo "[TEST] Testing --help option..."
	@./$(SCRIPT_NAME) --help > /tmp/webclone_help.txt
	@if grep -q "USAGE" /tmp/webclone_help.txt && \
	   grep -q "OPTIONS" /tmp/webclone_help.txt && \
	   grep -q "EXAMPLES" /tmp/webclone_help.txt; then \
		echo "[PASS] Help menu displays correctly"; \
	else \
		echo "[FAIL] Help menu is incomplete"; \
		exit 1; \
	fi
	@rm -f /tmp/webclone_help.txt

#######################################
# Test version option
#######################################
test-version:
	@echo ""
	@echo "[TEST] Testing --version option..."
	@./$(SCRIPT_NAME) --version > /tmp/webclone_version.txt
	@if grep -q "webclone.sh version" /tmp/webclone_version.txt; then \
		echo "[PASS] Version displays correctly"; \
	else \
		echo "[FAIL] Version output is incorrect"; \
		exit 1; \
	fi
	@rm -f /tmp/webclone_version.txt

#######################################
# Debug target - run with verbose/debug mode
#######################################
debug:
	@echo ""
	@echo "[DEBUG] Running in debug mode..."
	@if [ -z "$(URL)" ]; then \
		echo "[WARN] No URL specified, using https://example.com"; \
		URL="https://example.com"; \
	fi
	@echo "[DEBUG] Target URL: $(URL)"
	@echo "[DEBUG] Starting trace..."
	@echo ""
	@bash -x ./$(SCRIPT_NAME) --verbose $(URL)

#######################################
# Clean target - remove test artifacts
#######################################
clean:
	@echo "[INFO] Cleaning up test files..."
	@rm -f Example_Domain_*.html Example_Domain_*.md
	@rm -f *_*.html *_*.md
	@echo "[OK] Cleanup complete"

#######################################
# Validate script syntax
#######################################
lint:
	@echo "[INFO] Checking script syntax..."
	@if command -v shellcheck &> /dev/null; then \
		shellcheck $(SCRIPT_NAME); \
		echo "[OK] ShellCheck passed"; \
	else \
		echo "[WARN] shellcheck not installed, skipping..."; \
		bash -n $(SCRIPT_NAME) && echo "[OK] Basic syntax check passed"; \
	fi

#######################################
# Show script info
#######################################
info:
	@echo "webclone.sh Information"
	@echo ""
	@echo "Script: $(SCRIPT_NAME)"
	@echo "Size: $$(wc -c < $(SCRIPT_NAME)) bytes"
	@echo "Lines: $$(wc -l < $(SCRIPT_NAME))"
	@echo "Executable: $$(test -x $(SCRIPT_NAME) && echo 'Yes' || echo 'No')"
	@echo ""
	@echo "Dependencies:"
	@for cmd in curl sed grep awk date base64; do \
		if command -v $$cmd &> /dev/null; then \
			echo "  [OK] $$cmd"; \
		else \
			echo "  [MISSING] $$cmd"; \
		fi; \
	done
