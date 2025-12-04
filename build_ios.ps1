# سكريبت PowerShell لبناء iOS عبر GitHub Actions
# هذا السكريبت يسهل عملية البناء من Windows

Write-Host "`n=== بناء iOS عبر GitHub Actions ===" -ForegroundColor Cyan
Write-Host ""

# التحقق من وجود git
try {
    $gitVersion = git --version
    Write-Host "✅ Git موجود: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Git غير موجود. يرجى تثبيت Git أولاً." -ForegroundColor Red
    exit 1
}

# التحقق من وجود مستودع git
if (-not (Test-Path ".git")) {
    Write-Host "❌ هذا المجلد ليس مستودع Git." -ForegroundColor Red
    Write-Host "   قم بتشغيل: git init" -ForegroundColor Yellow
    exit 1
}

# التحقق من وجود remote
$remote = git remote get-url origin 2>$null
if (-not $remote) {
    Write-Host "⚠️  لا يوجد remote محدد." -ForegroundColor Yellow
    Write-Host "   يرجى إضافة remote أولاً:" -ForegroundColor Yellow
    Write-Host "   git remote add origin https://github.com/USERNAME/REPO.git" -ForegroundColor White
    exit 1
}

Write-Host "✅ Remote: $remote" -ForegroundColor Green
Write-Host ""

# سؤال المستخدم
Write-Host "اختر الإجراء:" -ForegroundColor Cyan
Write-Host "  1. دفع التغييرات وتشغيل البناء على GitHub" -ForegroundColor White
Write-Host "  2. فقط عرض رابط GitHub Actions" -ForegroundColor White
Write-Host "  3. إلغاء" -ForegroundColor White
Write-Host ""
$choice = Read-Host "اختيارك (1-3)"

switch ($choice) {
    "1" {
        Write-Host "`n=== دفع التغييرات ===" -ForegroundColor Cyan
        
        # التحقق من التغييرات
        $status = git status --porcelain
        if ($status) {
            Write-Host "`nالتغييرات الموجودة:" -ForegroundColor Yellow
            git status --short
            
            $commit = Read-Host "`nأدخل رسالة الـ commit (أو اضغط Enter للاستخدام الافتراضي)"
            if ([string]::IsNullOrWhiteSpace($commit)) {
                $commit = "Build iOS app - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            }
            
            Write-Host "`nإضافة التغييرات..." -ForegroundColor Yellow
            git add .
            
            Write-Host "إنشاء commit..." -ForegroundColor Yellow
            git commit -m $commit
            
            Write-Host "دفع إلى GitHub..." -ForegroundColor Yellow
            $branch = git branch --show-current
            git push origin $branch
            
            Write-Host "`n✅ تم الدفع بنجاح!" -ForegroundColor Green
            Write-Host ""
            Write-Host "الآن يمكنك:" -ForegroundColor Cyan
            Write-Host "  1. اذهب إلى: https://github.com/$($remote -replace '.*github.com[:/](.+?)(?:\.git)?$', '$1')/actions" -ForegroundColor White
            Write-Host "  2. اضغط على 'Build iOS' workflow" -ForegroundColor White
            Write-Host "  3. اضغط 'Run workflow' لبدء البناء" -ForegroundColor White
        } else {
            Write-Host "⚠️  لا توجد تغييرات للدفع." -ForegroundColor Yellow
            Write-Host "   يمكنك تشغيل البناء مباشرة من GitHub Actions." -ForegroundColor White
        }
    }
    "2" {
        $repoUrl = $remote -replace '\.git$', ''
        $actionsUrl = "$repoUrl/actions"
        Write-Host "`n=== رابط GitHub Actions ===" -ForegroundColor Cyan
        Write-Host $actionsUrl -ForegroundColor White
        Write-Host ""
        Write-Host "افتح الرابط أعلاه و:" -ForegroundColor Yellow
        Write-Host "  1. اضغط على 'Build iOS' workflow" -ForegroundColor White
        Write-Host "  2. اضغط 'Run workflow' لبدء البناء" -ForegroundColor White
    }
    "3" {
        Write-Host "تم الإلغاء." -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "❌ اختيار غير صحيح." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n=== انتهى ===" -ForegroundColor Green




