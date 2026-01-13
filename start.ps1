# Quick Start Script for AI Teaching Coach

Write-Host "🚀 Starting AI Teaching Coach Backend..." -ForegroundColor Green

# Check if Docker is running
try {
    docker ps | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Start services
Write-Host "`n📦 Starting services (PostgreSQL, MinIO, Backend)..." -ForegroundColor Cyan
docker-compose up -d

# Wait for services to be healthy
Write-Host "`n⏳ Waiting for services to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

# Check service status
Write-Host "`n📊 Service Status:" -ForegroundColor Cyan
docker-compose ps

# Show logs
Write-Host "`n📝 Backend Logs (Ctrl+C to stop viewing):" -ForegroundColor Cyan
Write-Host "To view logs later, run: docker-compose logs -f backend" -ForegroundColor Yellow
Write-Host ""

docker-compose logs -f backend
