# التحقق من حالة Git والكود
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "فحص حالة Git والكود" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location "D:\smsfllatter\untitled"

# 1. التحقق من حالة Git repository
Write-Host "[1] حالة Git Repository:" -ForegroundColor Yellow
try {
    $gitStatus = & git status --short 2>&1
    $fullStatus = & git status 2>&1 | Out-String
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Git repository موجود ويعمل" -ForegroundColor Green
        
        # عرض معلومات إضافية
        if ($fullStatus -match "On branch (\w+)") {
            $branch = $matches[1]
            Write-Host "   📍 الفرع الحالي: $branch" -ForegroundColor White
        }
        
        if ($gitStatus) {
            Write-Host "   ⚠️  توجد ملفات غير مضافة أو معدلة:" -ForegroundColor Yellow
            $gitStatus | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
        } else {
            Write-Host "   ✅ لا توجد تغييرات معلقة" -ForegroundColor Green
        }
    } else {
        Write-Host "   ❌ مشكلة في Git repository" -ForegroundColor Red
        Write-Host $gitStatus -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ خطأ: $_" -ForegroundColor Red
}

Write-Host ""

# 2. التحقق من الـ commits
Write-Host "[2] الـ Commits:" -ForegroundColor Yellow
try {
    $commits = & git log --oneline -5 2>&1
    if ($LASTEXITCODE -eq 0 -and $commits) {
        Write-Host "   ✅ يوجد commits:" -ForegroundColor Green
        $commits | Select-Object -First 3 | ForEach-Object {
            Write-Host "      $_" -ForegroundColor White
        }
        
        $commitCount = ($commits | Measure-Object).Count
        Write-Host "   📊 عدد الـ commits: $commitCount" -ForegroundColor White
    } else {
        Write-Host "   ⚠️  لا توجد commits بعد" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ خطأ في قراءة الـ commits" -ForegroundColor Red
}

Write-Host ""

# 3. التحقق من Remote
Write-Host "[3] Remote Repository:" -ForegroundColor Yellow
try {
    $remote = & git remote get-url origin 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Remote موجود: $remote" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Remote غير موجود" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ خطأ في قراءة Remote" -ForegroundColor Red
}

Write-Host ""

# 4. التحقق من حالة الرفع
Write-Host "[4] حالة الرفع إلى GitHub:" -ForegroundColor Yellow
try {
    $branch = & git branch --show-current 2>&1
    if ($LASTEXITCODE -eq 0 -and $branch) {
        $upstream = & git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ الفرع مربوط بـ: $upstream" -ForegroundColor Green
            
            # التحقق من الفرق بين local و remote
            $ahead = & git rev-list --count @{u}..HEAD 2>&1
            $behind = & git rev-list --count HEAD..@{u} 2>&1
            
            if ($ahead -gt 0) {
                Write-Host "   ⚠️  يوجد $ahead commits غير مرفوعة" -ForegroundColor Yellow
            } else {
                Write-Host "   ✅ جميع الـ commits مرفوعة" -ForegroundColor Green
            }
        } else {
            Write-Host "   ⚠️  الفرع غير مربوط بـ remote (لم يتم رفع الكود بعد)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  لا يمكن تحديد الفرع الحالي" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ خطأ في التحقق من حالة الرفع" -ForegroundColor Red
}

Write-Host ""

# 5. ملخص
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "الملخص:" -ForegroundColor Cyan

try {
    $status = & git status -sb 2>&1 | Select-Object -First 1
    Write-Host $status -ForegroundColor White
    
    if ($status -match "ahead") {
        Write-Host ""
        Write-Host "⚠️  الكود غير مرفوع إلى GitHub بعد" -ForegroundColor Yellow
        Write-Host "   قم بتشغيل: رفع_الكود.bat" -ForegroundColor White
    } elseif ($status -match "up to date") {
        Write-Host ""
        Write-Host "✅ الكود محدث ومرفوع إلى GitHub" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️  قد تحتاج إلى التحقق من حالة Git" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  لا يمكن تحديد الحالة بدقة" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan

