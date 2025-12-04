# سكريبت لرفع الكود تلقائياً إلى GitHub
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "رفع المشروع إلى GitHub تلقائياً" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# الانتقال إلى مجلد المشروع
Set-Location "D:\smsfllatter\untitled"

# 1. إضافة جميع الملفات
Write-Host "[1/4] إضافة جميع الملفات..." -ForegroundColor Yellow
& git add -A
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ تمت الإضافة بنجاح" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  قد تكون الملفات مضافة بالفعل" -ForegroundColor Yellow
}

Write-Host ""

# 2. إنشاء commit
Write-Host "[2/4] إنشاء commit..." -ForegroundColor Yellow
& git commit -m "iOS build ready - Initial commit"
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ تم إنشاء commit بنجاح" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  قد لا توجد تغييرات جديدة للـ commit" -ForegroundColor Yellow
}

Write-Host ""

# 3. ضبط الفرع إلى main
Write-Host "[3/4] ضبط الفرع إلى main..." -ForegroundColor Yellow
& git branch -M main 2>$null
Write-Host "   ✅ تم ضبط الفرع" -ForegroundColor Green

Write-Host ""

# 4. الدفع إلى GitHub
Write-Host "[4/4] رفع الكود إلى GitHub..." -ForegroundColor Yellow
Write-Host "   (قد تحتاج إلى تسجيل الدخول)" -ForegroundColor Gray
Write-Host ""
& git push -u origin main

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ تم رفع الكود بنجاح!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 الخطوات التالية:" -ForegroundColor Yellow
    Write-Host "   1. افتح: https://github.com/qutibalwaabi/aldafary-app/actions" -ForegroundColor White
    Write-Host "   2. اضغط على 'Build iOS'" -ForegroundColor White
    Write-Host "   3. اضغط 'Run workflow' → 'Run workflow'" -ForegroundColor White
    Write-Host "   4. انتظر 5-10 دقائق" -ForegroundColor White
    Write-Host "   5. حمّل ملف .ipa من Artifacts" -ForegroundColor White
    Write-Host ""
    
    # محاولة فتح المتصفح
    Start-Process "https://github.com/qutibalwaabi/aldafary-app/actions"
} else {
    Write-Host "⚠️  قد تحتاج إلى تسجيل الدخول إلى GitHub" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 الحلول:" -ForegroundColor Yellow
    Write-Host "   1. استخدم Source Control في Cursor:" -ForegroundColor White
    Write-Host "      - اضغط Ctrl+Shift+G" -ForegroundColor Gray
    Write-Host "      - اضغط على '...' → 'Push'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. أو أنشئ Personal Access Token:" -ForegroundColor White
    Write-Host "      https://github.com/settings/tokens" -ForegroundColor Gray
}

Write-Host "========================================" -ForegroundColor Cyan

