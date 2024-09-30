# Define the single command that runs both clean and build_runner
build:
	@echo "Cleaning and building with build_runner..."
	dart run build_runner clean
	dart run build_runner build --delete-conflicting-outputs

# Define the run target, which depends on the build target
run: build
	@echo "Running the Flutter app..."
	flutter run

# Phony target to prevent conflicts with files of the same name
.PHONY: build run
