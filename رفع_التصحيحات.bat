@echo off
chcp 65001 >nul
cls
echo ========================================
echo    رفع تصحيحات iOS Build Workflow
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] إضافة التغييرات...
git add .
echo Done!

echo.
echo [2/3] إنشاء commit...
git commit -m "Fix iOS build workflow - Update to v4 actions"
echo Done!

echo.
echo [3/3] رفع التغييرات...
git push origin main

echo.
echo ========================================
if %errorlevel% equ 0 (
    echo ✅ تم رفع التصحيحات بنجاح!
    echo.
    echo 📋 الخطوات التالية:
    echo 1. افتح: https://github.com/qutibalwaabi/aldafary-app/actions
    echo 2. اضغط على "Build iOS"
    echo 3. اضغط "Run workflow"
    echo 4. انتظر 5-10 دقائق
    echo.
    start https://github.com/qutibalwaabi/aldafary-app/actions
) else (
    echo ⚠️  قد تحتاج إلى تسجيل الدخول
    echo استخدم Token من GitHub
)
echo ========================================
pause

