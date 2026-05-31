Write-Host "Starting Stock Take System..." -ForegroundColor Green
Write-Host ""

# Start Docker
docker compose up -d

Write-Host "? Backend started at http://localhost:3000" -ForegroundColor Green
Write-Host "? Database started at port 5432" -ForegroundColor Green
Write-Host "? pgAdmin at http://localhost:5050" -ForegroundColor Green
Write-Host ""

# Start Admin Dashboard (Python needed)
Write-Host "To start Admin Dashboard, run in new terminal:" -ForegroundColor Yellow
Write-Host "cd admin-dashboard && python -m http.server 8080"
Write-Host ""

# Start Web App
Write-Host "To start Web App, run in new terminal:" -ForegroundColor Yellow
Write-Host "cd mobile && flutter run -d chrome"
