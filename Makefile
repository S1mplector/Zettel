APP_NAME := Zettel

.PHONY: build dmg

build:
	swift build

dmg:
	./scripts/package-dmg.sh
