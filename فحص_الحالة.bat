@echo off
chcp 65001 >nul
cls
echo ========================================
echo    فحص حالة Git والكود
echo ========================================
echo.

cd /d "%~dp0"

echo [1] حالة Git Repository:
git status --short
if %errorlevel% equ 0 (
    echo ✅ Git يعمل بشكل صحيح
) else (
    echo ❌ مشكلة في Git
)
echo.

echo [2] الـ Commits:
git log --oneline -3 2>nul
if %errorlevel% equ 0 (
    echo ✅ يوجد commits
) else (
    echo ⚠️  لا توجد commits بعد
)
echo.

echo [3] Remote Repository:
git remote -v
echo.

echo [4] حالة الرفع:
git status -sb
echo.

echo [5] الفرق بين Local و Remote:
git log origin/main..HEAD --oneline 2>nul
if %errorlevel% equ 0 (
    echo.
    echo ⚠️  يوجد commits غير مرفوعة
) else (
    echo ✅ لا يوجد commits غير مرفوعة أو لم يتم ربط Remote بعد
)
echo.

echo ========================================
echo.
echo 📋 الملخص:
echo.
git status -sb
echo.
echo ========================================
pause

