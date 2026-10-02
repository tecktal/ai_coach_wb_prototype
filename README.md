# AI Teaching Coach

Teachers record their classroom lessons on a phone. The AI Teaching Coach analyses each recording against the World Bank's **TEACH** classroom-observation framework, using Google Gemini, and returns per-element evidence, strengths and concrete recommendations. Users can then talk through the lesson with an AI coach. Pedagogy coordinators can record lessons they observe and get a guide for the coaching conversation that follows. Programme staff monitor adoption through a separate web dashboard.

**To install and deploy it, follow [DEPLOYMENT.md](DEPLOYMENT.md).**

## Quick start

Requires Docker and a [Gemini API key](https://aistudio.google.com/apikey).

```bash
git clone https://github.com/tecktal/ai_coach_wb_prototype.git ai_coach
cd ai_coach
git clone https://github.com/tecktal/ai_coach_monitoring_dashboard.git monitoring-dashboard

cp .env.example .env            # set GEMINI_API_KEY and JWT_SECRET
docker compose --profile dashboard up -d --build
```

- Backend: <http://localhost:8080/api/v1/health>
- Dashboard: <http://localhost:3000>
- App: `cd flutter_app && flutter pub get && flutter run -d chrome`

## Components

| Path | What | Stack |
|---|---|---|
| [`backend/`](backend/) | REST API, Gemini integration, Excel export | Go, Gin, PostgreSQL, MinIO |
| [`flutter_app/`](flutter_app/) | App for teachers and coordinators (Android, iOS, web, Windows), in English, French, Portuguese, Swahili and Amharic | Flutter |
| [`monitoring-dashboard`](https://github.com/tecktal/ai_coach_monitoring_dashboard) | Monitoring dashboard for admins and viewers (separate repository) | Next.js |

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md): installation, configuration, server deployment, operations
- [USER_ACCESS_CONTROL.md](USER_ACCESS_CONTROL.md): roles and what each can access
- [METADATA.md](METADATA.md): data the system collects
- [TESTING.md](TESTING.md): manual API testing

Backend tests: `cd backend && go test ./...`

## License

Prototype built for the World Bank TEACH initiative.
