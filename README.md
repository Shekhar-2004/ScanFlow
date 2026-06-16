# ScanFlow

A lightweight, offline-first document scanner focused on speed, simplicity, privacy, and excellent user experience.

Low-end device apk : https://drive.google.com/file/d/1CGOrY515IbupaefpgbACrgS8P2mnuOjY/view?usp=sharing

## Vision

Most modern scanner applications have become bloated with cloud integrations, mandatory accounts, AI upselling, analytics, and excessive permissions. ScanFlow aims to provide the core functionality users actually need—scanning documents, improving readability, generating PDFs, and sharing them—while remaining lightweight, fast, and privacy-friendly.

The goal is to become the best scanner app for everyday users.

## Core Principles

1. **Offline First**: The application works fully without internet access.
2. **Fast Launch**: Target startup time is < 2 seconds.
3. **Lightweight**: Optimized APK size to be as small as possible (target 25-40 MB).
4. **Privacy Respecting**: No account creation, no analytics, no mandatory cloud sync, no tracking.
5. **Beautiful Design**: A minimal, premium, and zero-visual-clutter interface where the scanned document is always the hero.

## Technology Stack

- **Framework**: Flutter & Dart
- **Navigation**: `go_router`
- **Camera**: `camera` package
- **Image Processing**: `image` package
- **PDF Generation**: `pdf` and `printing` packages
- **Storage**: `path_provider`
- **Sharing**: `share_plus`

## Features

- **Home Screen**: View recent documents and start a new scan.
- **Camera Screen**: Capture document images quickly and efficiently.
- **Editor Screen**: Crop, rotate, and apply essential filters (Original, Grayscale, High Contrast, Black & White).
- **PDF Preview**: Review generated PDFs, rename, and save.
- **Sharing**: Native sharing integration (WhatsApp, Gmail, Drive, etc.).

## Getting Started

This project is built using Flutter. To run it locally:

1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. Clone this repository:
   ```bash
   git clone https://github.com/Shekhar-2004/ScanFlow.git
   ```
3. Navigate to the project directory:
   ```bash
   cd ScanFirst
   ```
4. Install dependencies:
   ```bash
   flutter pub get
   ```
5. Run the application:
   ```bash
   flutter run
   ```

For more detailed technical guidelines, UI/UX specifications, and the full project master document, please refer to the internal `APP_DOC.txt` and `ScanFLow_UI_UX.txt` files.
