.PHONY: help build test

DEFAULT_DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

help:
	@echo "사용 가능한 명령어:"
	@echo "  make build  - 앱 번들 생성 및 설치"
	@echo "  make test   - swift test"

build:
	./build.sh

test:
	@if [ -z "$$DEVELOPER_DIR" ]; then \
		echo "DEVELOPER_DIR가 비어 있어 기본 경로를 사용합니다: $(DEFAULT_DEVELOPER_DIR)"; \
		DEVELOPER_DIR=$(DEFAULT_DEVELOPER_DIR) swift test; \
	else \
		echo "기존 DEVELOPER_DIR 사용: $$DEVELOPER_DIR"; \
		swift test; \
	fi
