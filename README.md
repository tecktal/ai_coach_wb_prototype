# AI Teaching Coach - Prototype

A cross-platform application that enables teachers to record classroom lessons and receive AI-powered analysis based on the World Bank's TEACH Primary observation framework.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Go](https://img.shields.io/badge/go-%2300ADD8.svg?style=for-the-badge&logo=go&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)

## Project Overview

This prototype uses **Gemini 2.5 Flash** (multimodal) to listen to classroom audio, transcribe it, and analyze it against the TEACH framework in a single pass.

**Key Features:**
*   **Audio Recording**: Record lessons directly in the app with pause/resume functionality.
*   **AI Analysis**: Automated scoring (1-5) on 9 teaching practices and "Time on Learning" snapshots.
*   **Feedback**: qualitative strengths, improvements, and actionable recommendations.
*   **Coaching Chat**: Chat with an AI coach about the specific lesson.
*   **Progress Tracking**: Track improvement over time.

## Getting Started

### Prerequisites

*   **Docker Desktop** (for running the backend services)
*   **Flutter SDK** (3.16+ recommended)
*   **Gemini API Key** (Get one from [Google AI Studio](https://aistudio.google.com/))

### 1. Backend Setup

The backend (Go), Database (Postgres), and Storage (MinIO) are containerized.

1.  Clone the repository.
2.  Copy `.env.example` to `.env`:
    ```bash
    cp .env.example .env
    ```
3.  Open `.env` and add your `GEMINI_API_KEY`.
4.  Start the services:

    ```bash
    docker-compose up -d --build
    ```

4.  Verify the backend is running at `http://localhost:8080/api/v1/health`.

### 2. Frontend Setup (Flutter App)

1.  Navigate to the app directory:
    ```bash
    cd flutter_app
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run the app:
    ```bash
    # For Chrome (Web)
    flutter run -d chrome

    # For Windows
    flutter run -d windows
    
    # For Android Emulator
    flutter run -d emulator-id
    ```

**Note for Android/iOS Devices:**
If running on a physical device, you need to change the API URL.
1.  Open `flutter_app/lib/core/constants/api_constants.dart`.
2.  Change `baseUrl` from `http://localhost:8080` to your computer's local IP address (e.g., `http://192.168.1.50:8080`).

## 🏗️ Architecture

*   **Frontend**: Flutter (Mobile/Web/Desktop)
*   **Backend**: Go (Gin Framework)
*   **AI**: Google Gemini 2.5 Flash
*   **Database**: PostgreSQL
*   **Storage**: MinIO (S3 compatible)

## Testing

To run the backend tests:
```bash
cd backend
go test ./...
```

## License

This project is a prototype built for the World Bank TEACH initiative.
