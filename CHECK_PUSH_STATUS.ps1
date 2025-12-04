# التحقق من حالة رفع الكود
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "فحص حالة رفع الكود إلى GitHub" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location "D:\smsfllatter\untitled"

# 1. التحقق من Remote
Write-Host "[1] Remote Repository:" -ForegroundColor Yellow
try {
    $remote = & git remote get-url origin 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Remote موجود: $remote" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Remote غير موجود" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ❌ خطأ: $_" -ForegroundColor Red
}

Write-Host ""

# 2. التحقق من Remote Tracking
Write-Host "[2] Remote Tracking Branch:" -ForegroundColor Yellow
try {
    $upstream = & git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>&1
    if ($LASTEXITCODE -eq 0 -and $upstream) {
        Write-Host "   ✅ الفرع مربوط بـ: $upstream" -ForegroundColor Green
        
        # التحقق من الفرق
        $aheadOutput = & git rev-list --count @{u}..HEAD 2>&1
        $aheadExitCode = $LASTEXITCODE
        $behindOutput = & git rev-list --count HEAD..@{u} 2>&1
        $behindExitCode = $LASTEXITCODE
        
        if ($aheadExitCode -eq 0 -and $behindExitCode -eq 0) {
            $ahead = [int]$aheadOutput
            $behind = [int]$behindOutput
            
            if ($ahead -gt 0) {
                Write-Host "   ⚠️  يوجد $ahead commits غير مرفوعة" -ForegroundColor Yellow
            } elseif ($behind -gt 0) {
                Write-Host "   ⚠️  Remote أمام بـ $behind commits" -ForegroundColor Yellow
            } else {
                Write-Host "   ✅ الكود محدث ومرفوع بالكامل!" -ForegroundColor Green
            }
        } else {
            Write-Host "   ⚠️  لا يمكن تحديد الفرق بين local و remote" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  الفرع غير مربوط بـ remote" -ForegroundColor Yellow
        
        # محاولة fetch للتحقق
        Write-Host "   جاري محاولة الاتصال..." -ForegroundColor Gray
        $fetchOutput = & git fetch origin 2>&1
        $fetchExitCode = $LASTEXITCODE
        
        if ($fetchExitCode -eq 0) {
            Write-Host "   ✅ تم الاتصال بنجاح!" -ForegroundColor Green
            
            # التحقق من وجود remote branch
            $remoteBranchOutput = & git ls-remote --heads origin main 2>&1
            $remoteBranchExitCode = $LASTEXITCODE
            
            if ($remoteBranchExitCode -eq 0 -and $remoteBranchOutput) {
                Write-Host "   ✅ Repository موجود على GitHub!" -ForegroundColor Green
                Write-Host "   ℹ️  تحتاج فقط إلى ربط الفرع:" -ForegroundColor Yellow
                Write-Host "      git branch --set-upstream-to=origin/main main" -ForegroundColor Gray
            } else {
                Write-Host "   ⚠️  لا يوجد remote branch بعد" -ForegroundColor Yellow
            }
        } else {
            $fetchError = $fetchOutput -join "`n"
            Write-Host "   ❌ فشل الاتصال:" -ForegroundColor Red
            Write-Host "      $fetchError" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ❌ خطأ: $_" -ForegroundColor Red
}

Write-Host ""

# 3. التحقق من Remote Branches
Write-Host "[3] Remote Branches:" -ForegroundColor Yellow
try {
    $remoteBranches = & git branch -r 2>&1
    if ($remoteBranches -and -not ($remoteBranches -match "error")) {
        Write-Host "   ✅ Remote branches موجودة:" -ForegroundColor Green
        $remoteBranches | ForEach-Object { 
            if ($_ -match "origin") {
                Write-Host "      $_" -ForegroundColor White
            }
        }
    } else {
        Write-Host "   ⚠️  لا توجد remote branches" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ خطأ: $_" -ForegroundColor Red
}

Write-Host ""

# 4. الحالة النهائية
Write-Host "[4] الحالة النهائية:" -ForegroundColor Yellow
try {
    $status = & git status -sb 2>&1 | Select-Object -First 1
    Write-Host "   $status" -ForegroundColor White
    
    if ($status -match "ahead") {
        Write-Host ""
        Write-Host "   ⚠️  الكود غير مرفوع بالكامل" -ForegroundColor Yellow
        Write-Host "   قم بتشغيل: git push -u origin main" -ForegroundColor Gray
    } elseif ($status -match "up to date" -or $status -match "Your branch is up to date") {
        Write-Host ""
        Write-Host "   ✅ الكود محدث ومرفوع بنجاح!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "   ℹ️  تحقق من التفاصيل أعلاه" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  لا يمكن تحديد الحالة بدقة" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

# 5. التحقق من Repository على GitHub
Write-Host ""
Write-Host "🔗 للتحقق من Repository على GitHub:" -ForegroundColor Cyan
Write-Host "   https://github.com/qutibalwaabi/aldafary-app" -ForegroundColor White
Write-Host ""
Write-Host "📱 للتحقق من Builds:" -ForegroundColor Cyan
Write-Host "   https://github.com/qutibalwaabi/aldafary-app/actions" -ForegroundColor White

