@echo off
chcp 65001 >nul
cls
echo ========================================
echo    فحص حالة رفع الكود
echo ========================================
echo.

cd /d "%~dp0"

echo [1] Remote Repository:
git remote -v
echo.

echo [2] Remote Tracking:
git branch -vv
echo.

echo [3] Remote Branches:
git branch -r
echo.

echo [4] الحالة:
git status -sb
echo.

echo [5] آخر Commit:
git log --oneline -1
echo.

echo ========================================
echo.
echo 🔗 رابط Repository:
echo    https://github.com/qutibalwaabi/aldafary-app
echo.
echo 📱 رابط Actions:
echo    https://github.com/qutibalwaabi/aldafary-app/actions
echo.
echo ========================================
pause

