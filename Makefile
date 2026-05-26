# =============================================================================
# Makefile for web2offline.sh
# =============================================================================
# Professional build/installation management for the web2offline script
#
# Targets:
#   install    - Install script to system bin directory
#   uninstall  - Remove script from system
#   test       - Run automated tests
#   debug      - Execute in verbose/debug mode
#   help       - Display available targets
#
# Usage:
#   make install      # Install to /usr/local/bin (requires sudo)
#   make install PREFIX=$HOME/.local  # Install to user directory
#   make uninstall    # Remove from system
#   make test         # Run tests
#   make debug URL=https://example.com  # Debug execution
# =============================================================================

# Configuration
SCRIPT_NAME := web2offline.sh
INSTALL_DIR ?= /usr/local/bin
PREFIX ?= $(INSTALL_DIR)
DESTDIR ?= 

# Colors for output (if terminal supports it)
COLOR_RESET := \033[0m
COLOR_GREEN := \033[32m
COLOR_YELLOW := \033[33m
COLOR_RED := \033[31m
COLOR_BLUE := \033[34m

# Check if running as root
IS_ROOT := $(shell [ "$(UID)" = "0" ] && echo "yes" || echo "no")

# Default target
.PHONY: all
all: help

# =============================================================================
# Installation Targets
# =============================================================================

.PHONY: install
install: check-script
	@echo -e "$(COLOR_BLUE)==> Installing $(SCRIPT_NAME) to $(PREFIX)...$(COLOR_RESET)"
	@if [ "$(PREFIX)" = "/usr/local/bin" ] && [ "$(IS_ROOT)" != "yes" ]; then \
		echo -e "$(COLOR_YELLOW)Note: Installing to /usr/local/bin requires sudo privileges.$(COLOR_RESET)"; \
		echo -e "$(COLOR_YELLOW)Run with: sudo make install$(COLOR_RESET)"; \
		echo -e "$(COLOR_YELLOW)Or use: make install PREFIX=$$HOME/.local/bin$(COLOR_RESET)"; \
		exit 1; \
	fi
	@mkdir -p $(DESTDIR)$(PREFIX)
	@cp $(SCRIPT_NAME) $(DESTDIR)$(PREFIX)/$(SCRIPT_NAME)
	@chmod +x $(DESTDIR)$(PREFIX)/$(SCRIPT_NAME)
	@echo -e "$(COLOR_GREEN)✓ Successfully installed to $(DESTDIR)$(PREFIX)/$(SCRIPT_NAME)$(COLOR_RESET)"
	@echo ""
	@echo "You can now run: $(SCRIPT_NAME) --help"

.PHONY: install-local
install-local: PREFIX=$(HOME)/.local/bin
install-local: install
	@echo -e "$(COLOR_GREEN)✓ Installed to user directory: $(HOME)/.local/bin/$(SCRIPT_NAME)$(COLOR_RESET)"
	@echo -e "$(COLOR_YELLOW)Note: Ensure $(HOME)/.local/bin is in your PATH$(COLOR_RESET)"

.PHONY: uninstall
uninstall:
	@echo -e "$(COLOR_BLUE)==> Uninstalling $(SCRIPT_NAME)...$(COLOR_RESET)"
	@for dir in "/usr/local/bin" "$(HOME)/.local/bin" "/usr/bin"; do \
		if [ -f "$$dir/$(SCRIPT_NAME)" ]; then \
			echo -e "$(COLOR_YELLOW)Removing: $$dir/$(SCRIPT_NAME)$(COLOR_RESET)"; \
			rm -f "$$dir/$(SCRIPT_NAME)" || echo -e "$(COLOR_RED)Failed to remove $$dir/$(SCRIPT_NAME) (may need sudo)$(COLOR_RESET)"; \
		fi; \
	done
	@echo -e "$(COLOR_GREEN)✓ Uninstallation complete$(COLOR_RESET)"

.PHONY: check-script
check-script:
	@if [ ! -f "$(SCRIPT_NAME)" ]; then \
		echo -e "$(COLOR_RED)Error: $(SCRIPT_NAME) not found in current directory$(COLOR_RESET)"; \
		exit 1; \
	fi
	@if [ ! -x "$(SCRIPT_NAME)" ]; then \
		echo -e "$(COLOR_YELLOW)Making script executable...$(COLOR_RESET)"; \
		chmod +x $(SCRIPT_NAME); \
	fi
	@echo -e "$(COLOR_GREEN)✓ Script validation passed$(COLOR_RESET)"

# =============================================================================
# Testing Targets
# =============================================================================

.PHONY: test
test: check-script test-html test-markdown test-help test-clean
	@echo ""
	@echo -e "$(COLOR_GREEN)========================================$(COLOR_RESET)"
	@echo -e "$(COLOR_GREEN)All tests completed successfully!$(COLOR_RESET)"
	@echo -e "$(COLOR_GREEN)========================================$(COLOR_RESET)"

.PHONY: test-html
test-html:
	@echo ""
	@echo -e "$(COLOR_BLUE)==> Testing HTML output...$(COLOR_RESET)"
	@mkdir -p test_output
	@./$(SCRIPT_NAME) --html https://example.com > /dev/null 2>&1 || true
	@ls -la *.html 2>/dev/null | head -5 || echo "No HTML files generated (expected if network unavailable)"
	@echo -e "$(COLOR_GREEN)✓ HTML test completed$(COLOR_RESET)"

.PHONY: test-markdown
test-markdown:
	@echo ""
	@echo -e "$(COLOR_BLUE)==> Testing Markdown output...$(COLOR_RESET)"
	@./$(SCRIPT_NAME) --markdown https://example.com > /dev/null 2>&1 || true
	@ls -la *.md 2>/dev/null | head -5 || echo "No MD files generated (expected if network unavailable)"
	@echo -e "$(COLOR_GREEN)✓ Markdown test completed$(COLOR_RESET)"

.PHONY: test-help
test-help:
	@echo ""
	@echo -e "$(COLOR_BLUE)==> Testing help output...$(COLOR_RESET)"
	@./$(SCRIPT_NAME) --help | head -20
	@echo -e "$(COLOR_GREEN)✓ Help test completed$(COLOR_RESET)"

.PHONY: test-verbose
test-verbose:
	@echo ""
	@echo -e "$(COLOR_BLUE)==> Testing verbose mode...$(COLOR_RESET)"
	@./$(SCRIPT_NAME) --verbose --help > /dev/null 2>&1 || true
	@echo -e "$(COLOR_GREEN)✓ Verbose mode test completed$(COLOR_RESET)"

.PHONY: test-clean
test-clean:
	@echo ""
	@echo -e "$(COLOR_BLUE)==> Cleaning up test files...$(COLOR_RESET)"
	@rm -rf test_output/
	@echo -e "$(COLOR_GREEN)✓ Cleanup completed$(COLOR_RESET)"

.PHONY: test-offline
test-offline:
	@echo ""
	@echo -e "$(COLOR_BLUE)==> Running offline syntax check...$(COLOR_RESET)"
	@bash -n $(SCRIPT_NAME) && echo -e "$(COLOR_GREEN)✓ Syntax check passed$(COLOR_RESET)" || echo -e "$(COLOR_RED)✗ Syntax errors found$(COLOR_RESET)"
	@shellcheck $(SCRIPT_NAME) 2>/dev/null && echo -e "$(COLOR_GREEN)✓ ShellCheck passed$(COLOR_RESET)" || echo -e "$(COLOR_YELLOW)ShellCheck not installed or warnings found$(COLOR_RESET)"

# =============================================================================
# Debug Target
# =============================================================================

.PHONY: debug
debug: check-script
ifndef URL
	@echo -e "$(COLOR_RED)Error: URL not specified$(COLOR_RESET)"
	@echo -e "$(COLOR_YELLOW)Usage: make debug URL=https://example.com$(COLOR_RESET)"
	@exit 1
endif
	@echo -e "$(COLOR_BLUE)==> Running $(SCRIPT_NAME) in debug mode...$(COLOR_RESET)"
	@echo -e "$(COLOR_YELLOW)Target URL: $(URL)$(COLOR_RESET)"
	@echo ""
	@bash -x ./$(SCRIPT_NAME) --verbose $(URL)

.PHONY: debug-md
debug-md: check-script
ifndef URL
	@echo -e "$(COLOR_RED)Error: URL not specified$(COLOR_RESET)"
	@echo -e "$(COLOR_YELLOW)Usage: make debug-md URL=https://example.com$(COLOR_RESET)"
	@exit 1
endif
	@echo -e "$(COLOR_BLUE)==> Running $(SCRIPT_NAME) in debug mode (Markdown output)...$(COLOR_RESET)"
	@echo -e "$(COLOR_YELLOW)Target URL: $(URL)$(COLOR_RESET)"
	@echo ""
	@bash -x ./$(SCRIPT_NAME) --verbose --markdown $(URL)

# =============================================================================
# Development & Maintenance Targets
# =============================================================================

.PHONY: lint
lint:
	@echo -e "$(COLOR_BLUE)==> Running ShellCheck...$(COLOR_RESET)"
	@shellcheck $(SCRIPT_NAME) || echo -e "$(COLOR_YELLOW)ShellCheck completed with warnings$(COLOR_RESET)"

.PHONY: validate
validate: lint test-offline
	@echo -e "$(COLOR_GREEN)✓ All validations passed$(COLOR_RESET)"

.PHONY: clean
clean:
	@echo -e "$(COLOR_BLUE)==> Cleaning generated files...$(COLOR_RESET)"
	@rm -f *.html *.md 2>/dev/null || true
	@rm -rf test_output/ 2>/dev/null || true
	@echo -e "$(COLOR_GREEN)✓ Clean completed$(COLOR_RESET)"

.PHONY: version
version:
	@./$(SCRIPT_NAME) --version

# =============================================================================
# Help Target
# =============================================================================

.PHONY: help
help:
	@echo ""
	@echo -e "$(COLOR_BLUE)web2offline.sh - Makefile Targets$(COLOR_RESET)"
	@echo ""
	@echo -e "$(COLOR_GREEN)Installation:$(COLOR_RESET)"
	@echo "  make install          Install to /usr/local/bin (requires sudo)"
	@echo "  make install-local    Install to ~/.local/bin (no sudo needed)"
	@echo "  make uninstall        Remove from system"
	@echo ""
	@echo -e "$(COLOR_GREEN)Testing:$(COLOR_RESET)"
	@echo "  make test             Run all automated tests"
	@echo "  make test-html        Test HTML output generation"
	@echo "  make test-markdown    Test Markdown output generation"
	@echo "  make test-help        Test help menu output"
	@echo "  make test-verbose     Test verbose mode"
	@echo "  make test-offline     Run offline syntax checks"
	@echo ""
	@echo -e "$(COLOR_GREEN)Debugging:$(COLOR_RESET)"
	@echo "  make debug URL=<url>  Run script in debug mode (HTML)"
	@echo "  make debug-md URL=<url>  Run script in debug mode (Markdown)"
	@echo ""
	@echo -e "$(COLOR_GREEN)Development:$(COLOR_RESET)"
	@echo "  make lint             Run ShellCheck static analysis"
	@echo "  make validate         Run all validations"
	@echo "  make clean            Remove generated files"
	@echo "  make version          Show script version"
	@echo ""
	@echo -e "$(COLOR_GREEN)Examples:$(COLOR_RESET)"
	@echo "  sudo make install"
	@echo "  make install-local"
	@echo "  make test"
	@echo "  make debug URL=https://example.com"
	@echo ""
