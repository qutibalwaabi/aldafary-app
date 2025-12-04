@echo off
chcp 65001 >nul
cls
echo ========================================
echo    إنشاء Repository على GitHub
echo ========================================
echo.

echo ⚠️  Repository غير موجود على GitHub!
echo.
echo 📋 الخطوات:
echo.
echo 1. سيتم فتح صفحة إنشاء Repository
echo 2. Repository name: aldafary-app
echo 3. اختر Private أو Public
echo 4. لا تضع علامة على "Initialize with README"
echo 5. اضغط "Create repository"
echo.
pause

start https://github.com/new

echo.
echo ========================================
echo بعد إنشاء Repository:
echo.
echo 1. شغّل: رفع_الكود.bat مرة أخرى
echo 2. أو استخدم Source Control في Cursor
echo.
echo ========================================
pause

