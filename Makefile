# Common build steps
.PHONY: clean build run run-release gen-debug

# Clean and generate code using build_runner
build:
	@echo "Cleaning and building with build_runner..."
	dart run build_runner clean
	dart run build_runner build --delete-conflicting-outputs

# Run the Flutter app in debug mode
run: build
	@echo "Running the Flutter app in debug mode..."
	flutter run

# Run the Flutter app in release mode
run-release: build
	@echo "Running the Flutter app in release mode..."
	flutter run --release

# Generate a debug APK
gen-debug: build
	@echo "Building debug APK..."
	flutter build apk --debug
