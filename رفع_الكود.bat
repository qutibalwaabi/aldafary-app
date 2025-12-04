@echo off
chcp 65001 >nul
cls
echo ========================================
echo    رفع المشروع إلى GitHub تلقائياً
echo ========================================
echo.

cd /d "%~dp0"

echo [1/4] إضافة جميع الملفات...
git add -A
echo Done!

echo.
echo [2/4] إنشاء commit...
git commit -m "iOS build ready - Initial commit"
echo Done!

echo.
echo [3/4] ضبط الفرع إلى main...
git branch -M main >nul 2>&1
echo Done!

echo.
echo [4/4] رفع الكود إلى GitHub...
echo.
echo ⚠️  قد تحتاج إلى تسجيل الدخول
echo.
git push -u origin main

echo.
echo ========================================
if %errorlevel% equ 0 (
    echo ✅ تم رفع الكود بنجاح!
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
    echo.
    echo 💡 إذا فشل الدفع:
    echo.
    echo استخدم Source Control في Cursor:
    echo 1. اضغط Ctrl+Shift+G
    echo 2. اضغط على "..." في الأعلى
    echo 3. اختر "Push" أو "Publish Branch"
    echo.
)
echo ========================================
pause

