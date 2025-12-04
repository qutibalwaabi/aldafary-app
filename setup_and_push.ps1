# Setup Git and Push to GitHub
Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     تهيئة Git ورفع المشروع إلى GitHub                     ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$username = "qutibalwaabi"
$repoName = "aldafary-app"
$repoUrl = "https://github.com/$username/$repoName.git"

# Initialize Git
if (-not (Test-Path ".git")) {
    Write-Host "📦 تهيئة Git repository..." -ForegroundColor Yellow
    git init
    Write-Host "✅ تم إنشاء Git repository" -ForegroundColor Green
} else {
    Write-Host "✅ Git repository موجود بالفعل" -ForegroundColor Green
}

# Check/add remote
$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    Write-Host "🔄 تحديث remote..." -ForegroundColor Yellow
    git remote set-url origin $repoUrl
    Write-Host "✅ تم تحديث remote إلى: $repoUrl" -ForegroundColor Green
} else {
    Write-Host "➕ إضافة remote..." -ForegroundColor Yellow
    git remote add origin $repoUrl
    Write-Host "✅ تم إضافة remote: $repoUrl" -ForegroundColor Green
}

# Add all files
Write-Host "`n📁 إضافة الملفات..." -ForegroundColor Yellow
git add .
Write-Host "✅ تم إضافة الملفات" -ForegroundColor Green

# Commit
$commitMessage = "Prepare iOS build - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "💾 إنشاء commit..." -ForegroundColor Yellow
git commit -m $commitMessage
Write-Host "✅ تم إنشاء commit" -ForegroundColor Green

# Set branch to main
Write-Host "🌿 ضبط الفرع إلى main..." -ForegroundColor Yellow
git branch -M main 2>$null

# Push to GitHub
Write-Host "`n📤 جاري الدفع إلى GitHub..." -ForegroundColor Cyan
Write-Host "⚠️  قد يطلب منك تسجيل الدخول إلى GitHub" -ForegroundColor Yellow
Write-Host ""

$pushOutput = git push -u origin main 2>&1 | Out-String

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║     ✅ تم الدفع بنجاح!                                    ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔗 رابط Repository:" -ForegroundColor Cyan
    Write-Host "   https://github.com/$username/$repoName" -ForegroundColor White
    Write-Host ""
    Write-Host "⚙️  رابط GitHub Actions:" -ForegroundColor Cyan
    Write-Host "   https://github.com/$username/$repoName/actions" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 الخطوات التالية:" -ForegroundColor Yellow
    Write-Host "   1. افتح: https://github.com/$username/$repoName/actions" -ForegroundColor White
    Write-Host "   2. اضغط على 'Build iOS'" -ForegroundColor White
    Write-Host "   3. اضغط 'Run workflow' → 'Run workflow'" -ForegroundColor White
    Write-Host "   4. انتظر 5-10 دقائق" -ForegroundColor White
    Write-Host "   5. حمّل ملف .ipa من Artifacts" -ForegroundColor White
    
    # Try to open browser
    Start-Sleep -Seconds 2
    Start-Process "https://github.com/$username/$repoName/actions"
} else {
    Write-Host "`n❌ حدثت مشكلة أثناء الدفع:" -ForegroundColor Red
    Write-Host $pushOutput -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 الحلول الممكنة:" -ForegroundColor Yellow
    Write-Host "   1. تأكد من إنشاء repository على GitHub:" -ForegroundColor White
    Write-Host "      https://github.com/new" -ForegroundColor Gray
    Write-Host "      اسم Repository: $repoName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. أو استخدم repository موجود:" -ForegroundColor White
    Write-Host "      git remote set-url origin https://github.com/$username/REPO-NAME.git" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   3. تأكد من تسجيل الدخول إلى Git:" -ForegroundColor White
    Write-Host "      git config --global user.name 'Your Name'" -ForegroundColor Gray
    Write-Host "      git config --global user.email 'your.email@example.com'" -ForegroundColor Gray
}



