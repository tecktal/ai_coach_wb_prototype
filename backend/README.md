# AI Coach - Backend (Go)

Welcome to the backend repository of the **AI Coach** project. 

## Project Context
The **AI Coach** is an innovative educational technology initiative developed for **The World Bank**. The project's primary goal is to empower educators across various countries (including Senegal, Ethiopia, Tanzania, and Seychelles) by providing them with an intelligent, automated teaching assistant. 

Teachers can record their classroom lessons, which are then analyzed using advanced Artificial Intelligence. The core of this analysis is grounded in The World Bank's highly regarded **TEACH Primary observation framework**, a globally recognized tool designed to track and improve teaching quality in primary school classrooms. By leveraging AI, the project scales the delivery of personalized, actionable feedback to teachers, helping them refine their pedagogical skills and ultimately improving student learning outcomes in developing nations.

## Role of the Backend
This repository contains the robust, scalable backend service written in **Go**. It acts as the central hub of the AI Coach ecosystem. Its primary responsibilities include:
- **Audio Processing & Storage**: Securely handling and storing classroom audio recordings from the frontend client.
- **AI Integration**: Orchestrating complex interactions with the Google **Gemini API** to transcribe long-form classroom audio and perform deep, context-aware analysis against the TEACH framework.
- **Data Management**: Providing a reliable persistence layer (using PostgreSQL and MinIO) for user profiles, lesson metadata, and generated assessment reports.
- **API Services**: Serving secure, high-performance RESTful JSON endpoints to power the Flutter mobile/web application.

![Go](https://img.shields.io/badge/go-%2300ADD8.svg?style=for-the-badge&logo=go&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)

## Features
*   **AI Analysis Integration**: Uses Google's Gemini API to parse and analyze classroom audio.
*   **Data Models**: Manages lessons, user profiles, and assessment reports.
*   **RESTful API**: Serves JSON endpoints for the Flutter frontend application.

## Getting Started

The backend, database and storage run together from the `docker-compose.yml` at the **repository root**. See [DEPLOYMENT.md](../DEPLOYMENT.md) for the full setup.

### Running the backend outside Docker (development)

Requires Go 1.24+. Start only the database and storage from the repository root, then run the server locally:

```bash
# repository root
docker compose up -d ai_coach_db minio

# backend/
cp .env.example .env      # set GEMINI_API_KEY and JWT_SECRET; match the DB/MinIO credentials in the root .env
go run ./cmd/server       # http://localhost:8080/api/v1/health
```

The schema is created and migrated automatically on startup (`internal/database/migrations.go`).

### Testing

To run the backend tests:
```bash
go test ./...
```
