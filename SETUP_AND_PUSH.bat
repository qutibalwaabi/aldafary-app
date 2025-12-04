@echo off
chcp 65001 >nul
echo ========================================
echo تهيئة Git ورفع المشروع إلى GitHub
echo ========================================
echo.

echo [1/6] إعداد Git config...
REM محاولة استخدام إعدادات Git الموجودة أو استخدام القيم الافتراضية
git config user.name "qutibalwaabi" || git config --global user.name "qutibalwaabi"
git config user.email "qutibalwaabi@users.noreply.github.com" || git config --global user.email "qutibalwaabi@users.noreply.github.com"
echo Done!

echo.
echo [2/6] إضافة remote...
git remote remove origin 2>nul
git remote add origin https://github.com/qutibalwaabi/aldafary-app.git
if %errorlevel% neq 0 (
    git remote set-url origin https://github.com/qutibalwaabi/aldafary-app.git
)
echo Done!

echo.
echo [3/6] إضافة جميع الملفات...
git add .
echo Done!

echo.
echo [4/6] إنشاء commit...
git commit -m "iOS build ready - Initial commit"
echo Done!

echo.
echo [5/6] ضبط الفرع إلى main...
git branch -M main 2>nul
if %errorlevel% neq 0 (
    git checkout -b main
)
echo Done!

echo.
echo [6/6] الدفع إلى GitHub...
echo (قد تحتاج إلى إدخال بيانات GitHub)
echo.
git push -u origin main

echo.
echo ========================================
if %errorlevel% equ 0 (
    echo SUCCESS! تم رفع الكود بنجاح
    echo.
    echo الخطوات التالية:
    echo 1. افتح: https://github.com/qutibalwaabi/aldafary-app/actions
    echo 2. اضغط على "Build iOS"
    echo 3. اضغط "Run workflow"
    echo 4. انتظر 5-10 دقائق
    echo 5. حمّل ملف .ipa من Artifacts
    echo.
    start https://github.com/qutibalwaabi/aldafary-app/actions
) else (
    echo قد تحتاج إلى تسجيل الدخول إلى GitHub
    echo أنشئ Personal Access Token من:
    echo https://github.com/settings/tokens
)
echo ========================================
pause

