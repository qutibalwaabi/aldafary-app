# Check GitHub Account from Cursor/VSCode
Write-Host "=== التحقق من حساب GitHub ===" -ForegroundColor Cyan
Write-Host ""

# Check Git global config
Write-Host "[1] Git Global Config:" -ForegroundColor Yellow
$globalConfig = "$env:USERPROFILE\.gitconfig"
if (Test-Path $globalConfig) {
    Write-Host "   ملف Git Config موجود" -ForegroundColor Green
    Get-Content $globalConfig | Select-String -Pattern "user\.|github" | ForEach-Object {
        Write-Host "   $_" -ForegroundColor White
    }
} else {
    Write-Host "   ملف Git Config غير موجود" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2] Git Local Config (هذا المشروع):" -ForegroundColor Yellow
if (Test-Path ".git\config") {
    Get-Content ".git\config" | Select-String -Pattern "user\.|remote" | ForEach-Object {
        Write-Host "   $_" -ForegroundColor White
    }
} else {
    Write-Host "   لا يوجد Git repository" -ForegroundColor Red
}

Write-Host ""
Write-Host "[3] محاولة قراءة من Git مباشرة:" -ForegroundColor Yellow
try {
    $userName = & git config --global user.name 2>&1
    $userEmail = & git config --global user.email 2>&1
    
    if ($userName -and -not ($userName -match "error")) {
        Write-Host "   اسم المستخدم: $userName" -ForegroundColor Green
    } else {
        Write-Host "   اسم المستخدم: غير محدد" -ForegroundColor Yellow
    }
    
    if ($userEmail -and -not ($userEmail -match "error")) {
        Write-Host "   البريد الإلكتروني: $userEmail" -ForegroundColor Green
    } else {
        Write-Host "   البريد الإلكتروني: غير محدد" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   لا يمكن قراءة Git config" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4] التحقق من Windows Credential Manager:" -ForegroundColor Yellow
try {
    $creds = cmdkey /list 2>&1 | Select-String -Pattern "git|github"
    if ($creds) {
        Write-Host "   وجدت بيانات اعتماد GitHub:" -ForegroundColor Green
        $creds | ForEach-Object { Write-Host "   $_" -ForegroundColor White }
    } else {
        Write-Host "   لا توجد بيانات اعتماد محفوظة في Credential Manager" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   لا يمكن الوصول إلى Credential Manager" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== النتيجة ===" -ForegroundColor Cyan
Write-Host "إذا كان حسابك مسجل في Cursor/VSCode، سأستخدم بياناته تلقائياً" -ForegroundColor White

