# Build iOS Now - Script
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building iOS App for GitHub Actions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Add remote if not exists
Write-Host "[1/5] Checking remote..." -ForegroundColor Yellow
$remoteExists = git remote get-url origin 2>$null
if (-not $remoteExists) {
    git remote add origin https://github.com/qutibalwaabi/aldafary-app.git
    Write-Host "   Added remote" -ForegroundColor Green
} else {
    Write-Host "   Remote exists: $remoteExists" -ForegroundColor Green
}

# Step 2: Add all files
Write-Host "[2/5] Adding files..." -ForegroundColor Yellow
git add . 2>&1 | Out-Null
Write-Host "   Files added" -ForegroundColor Green

# Step 3: Create commit
Write-Host "[3/5] Creating commit..." -ForegroundColor Yellow
git commit -m "iOS build ready - $(Get-Date -Format 'yyyyMMdd-HHmmss')" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   Commit created" -ForegroundColor Green
} else {
    Write-Host "   Commit may already exist or no changes" -ForegroundColor Yellow
}

# Step 4: Set branch to main
Write-Host "[4/5] Setting branch..." -ForegroundColor Yellow
$currentBranch = git branch --show-current
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    git checkout -b main 2>&1 | Out-Null
} else {
    if ($currentBranch -ne "main") {
        git branch -M main 2>&1 | Out-Null
    }
}
Write-Host "   Branch set to main" -ForegroundColor Green

# Step 5: Push to GitHub
Write-Host "[5/5] Pushing to GitHub..." -ForegroundColor Yellow
Write-Host "   (This may require authentication)" -ForegroundColor Gray
$pushResult = git push -u origin main 2>&1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS! Code pushed to GitHub" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Open: https://github.com/qutibalwaabi/aldafary-app/actions" -ForegroundColor White
    Write-Host "2. Click 'Build iOS' workflow" -ForegroundColor White
    Write-Host "3. Click 'Run workflow' button" -ForegroundColor White
    Write-Host "4. Wait 5-10 minutes" -ForegroundColor White
    Write-Host "5. Download .ipa from Artifacts" -ForegroundColor White
    Write-Host ""
    
    # Try to open browser
    Start-Sleep -Seconds 1
    Start-Process "https://github.com/qutibalwaabi/aldafary-app/actions"
} else {
    Write-Host "Push result:" -ForegroundColor Yellow
    Write-Host $pushResult -ForegroundColor White
    Write-Host ""
    Write-Host "If authentication failed:" -ForegroundColor Yellow
    Write-Host "- Create Personal Access Token on GitHub" -ForegroundColor White
    Write-Host "- Use token as password when prompted" -ForegroundColor White
}
Write-Host "========================================" -ForegroundColor Cyan

