# Makefile for thesis-management-tools

.PHONY: help validate-yaml test lint clean

# Default target
help:
	@echo "Available targets:"
	@echo "  validate-yaml  - Run YAML workflow validation (yamllint + actionlint)"
	@echo "  test          - Run all tests"
	@echo "  lint          - Run linting checks"
	@echo "  clean         - Clean temporary files"
	@echo "  help          - Show this help message"

# YAML validation
validate-yaml:
	@echo "Running YAML workflow validation..."
	@./scripts/validate-yaml.sh

# Test target (placeholder for future tests)
test:
	@echo "Running tests..."
	@echo "TODO: Add test commands here"

# Lint target (placeholder for future linting)
lint:
	@echo "Running lint checks..."
	@echo "TODO: Add lint commands here"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@find . -name "*.tmp" -type f -delete
	@find . -name "*.log" -type f -delete
	@echo "Clean complete"