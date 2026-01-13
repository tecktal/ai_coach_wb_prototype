# AI Coach - Flutter App

This is the frontend application for the AI Coach.

## Run Instructions

1.  Ensure the backend is running (see root `README.md`).
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run:
    ```bash
    flutter run
    ```

## Configuration

To connect to a backend running on a different machine (or if using a physical device), update `lib/core/constants/api_constants.dart`:

```dart
static const String baseUrl = 'http://<YOUR_IP>:8080';
```
