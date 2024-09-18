# Omada Portal Client

## Overview

This is a client application designed for interacting with the Omada Portal API. It allows for real-time monitoring of network clients, including session details and remaining usage time.

## Prerequisites

- Ensure that you have configured the `.env` file with the necessary environment variables before running the application.
- Dart SDK should be installed on your machine.

## Setup Instructions

1. Update the `.env` file with your specific configurations, such as API credentials and URLs.
2. To generate the necessary files and code, run the following command in your project directory:
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```
