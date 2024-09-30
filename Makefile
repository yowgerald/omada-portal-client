
build:
	@echo "Cleaning and building with build_runner..."
	dart run build_runner clean
	dart run build_runner build --delete-conflicting-outputs

run: build
	@echo "Running the Flutter app..."
	flutter run

run-release: build
	flutter run --release

# Phony target to prevent conflicts with files of the same name
.PHONY: build run
