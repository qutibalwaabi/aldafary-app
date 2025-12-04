@echo off
chcp 65001 >nul
echo ========================================
echo Building iOS App for GitHub
echo ========================================
echo.

echo [1/5] Adding remote...
git remote remove origin 2>nul
git remote add origin https://github.com/qutibalwaabi/aldafary-app.git
if %errorlevel% neq 0 (
    git remote set-url origin https://github.com/qutibalwaabi/aldafary-app.git
)
echo Done!

echo.
echo [2/5] Adding files...
git add .
echo Done!

echo.
echo [3/5] Creating commit...
git commit -m "iOS build ready"
echo Done!

echo.
echo [4/5] Setting branch to main...
git branch -M main
echo Done!

echo.
echo [5/5] Pushing to GitHub...
echo (You may need to enter GitHub credentials)
echo.
git push -u origin main

echo.
echo ========================================
if %errorlevel% equ 0 (
    echo SUCCESS! Code pushed to GitHub
    echo.
    echo Next steps:
    echo 1. Open: https://github.com/qutibalwaabi/aldafary-app/actions
    echo 2. Click "Build iOS" workflow
    echo 3. Click "Run workflow" button
    echo 4. Wait 5-10 minutes
    echo 5. Download .ipa from Artifacts
    echo.
    start https://github.com/qutibalwaabi/aldafary-app/actions
) else (
    echo Push may require authentication
    echo Create Personal Access Token on GitHub if needed
)
echo ========================================
pause

