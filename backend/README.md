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

### Prerequisites

*   **Docker Desktop** (for running the backend services)
*   **Go 1.22+**
*   **Gemini API Key** (Get one from [Google AI Studio](https://aistudio.google.com/))

### Setup

The backend logic, Database (Postgres), and Storage (MinIO) are containerized for easy setup.

1.  Copy `.env.example` to `.env`:
    ```bash
    cp .env.example .env
    ```
2.  Open `.env` and add your actual API keys (such as `GEMINI_API_KEY`).
3.  Start the services:
    ```bash
    docker-compose up -d --build
    ```
4.  Verify the backend is running by navigating your browser to `http://localhost:8080/api/v1/health`.

### Testing

To run the backend tests:
```bash
go test ./...
```
