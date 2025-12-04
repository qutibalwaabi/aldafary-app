# سكريبت مباشر لبناء iOS عبر GitHub Actions
Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     بناء نسخة iOS - مباشر                                 ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# التحقق من Git
if (-not (Test-Path ".git")) {
    Write-Host "إنشاء Git repository..." -ForegroundColor Yellow
    git init | Out-Null
    Write-Host "✅ تم إنشاء Git repository" -ForegroundColor Green
}

# التحقق من GitHub remote
$remote = git remote get-url origin 2>$null
if ([string]::IsNullOrWhiteSpace($remote)) {
    Write-Host "`n❌ لا يوجد GitHub repository مرتبط" -ForegroundColor Red
    Write-Host "`n📋 يجب عليك:" -ForegroundColor Yellow
    Write-Host "1. إنشاء repository جديد على GitHub.com" -ForegroundColor White
    Write-Host "2. ربطه بالمشروع باستخدام:" -ForegroundColor White
    Write-Host "   git remote add origin https://github.com/USERNAME/REPO.git" -ForegroundColor Gray
    Write-Host "3. إعادة تشغيل هذا السكريبت" -ForegroundColor White
    exit 1
}

Write-Host "✅ GitHub repository: $remote" -ForegroundColor Green

# إضافة الملفات
Write-Host "`nإضافة الملفات..." -ForegroundColor Yellow
git add . 2>&1 | Out-Null

# Commit
$commitMessage = "Build iOS app - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "إنشاء commit..." -ForegroundColor Yellow
git commit -m $commitMessage 2>&1 | Out-Null

# الحصول على اسم الفرع
$branch = git branch --show-current
if ([string]::IsNullOrWhiteSpace($branch)) {
    $branch = "main"
    git branch -M main 2>&1 | Out-Null
}

# دفع إلى GitHub
Write-Host "دفع إلى GitHub..." -ForegroundColor Yellow
$pushResult = git push origin $branch 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ تم الدفع بنجاح!" -ForegroundColor Green
    
    # استخراج رابط GitHub
    $repoUrl = $remote -replace '\.git$', ''
    $actionsUrl = "$repoUrl/actions"
    
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║     ✅ الكود تم دفعه بنجاح!                               ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📱 الآن قم بالخطوات التالية:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. افتح هذا الرابط:" -ForegroundColor Yellow
    Write-Host "   $actionsUrl" -ForegroundColor White
    Write-Host ""
    Write-Host "2. اضغط على 'Build iOS' من القائمة" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "3. اضغط 'Run workflow' → 'Run workflow'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. انتظر 5-10 دقائق حتى يكتمل البناء" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "5. بعد اكتمال البناء، اضغط على 'ios-app' artifact" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "6. حمّل ملف .ipa" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⚠️  لا يمكن بناء iOS على Windows محلياً" -ForegroundColor Red
    Write-Host "   يجب استخدام GitHub Actions (مجاني)" -ForegroundColor Gray
    
    # محاولة فتح المتصفح
    Start-Sleep -Seconds 2
    Start-Process $actionsUrl
} else {
    Write-Host "❌ فشل الدفع إلى GitHub" -ForegroundColor Red
    Write-Host $pushResult -ForegroundColor Red
    Write-Host "`nتحقق من:" -ForegroundColor Yellow
    Write-Host "- أنك قمت بتسجيل الدخول إلى Git" -ForegroundColor White
    Write-Host "- أن لديك صلاحية على Repository" -ForegroundColor White
}




