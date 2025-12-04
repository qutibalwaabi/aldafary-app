@echo off
chcp 65001 >nul
cls
echo ========================================
echo    رفع الكود باستخدام Token
echo ========================================
echo.

cd /d "%~dp0"

echo ⚠️  مهم: ستحتاج إلى GitHub Personal Access Token
echo.
echo خطوات الحصول على Token:
echo 1. افتح: https://github.com/settings/tokens
echo 2. اضغط "Generate new token (classic)"
echo 3. اختر صلاحيات: repo (كلها)
echo 4. انسخ الـ Token
echo.
pause

echo.
echo [1/3] إضافة الملفات...
git add -A
echo Done!

echo.
echo [2/3] إنشاء commit...
git commit -m "iOS build ready - Initial commit"
echo Done!

echo.
echo [3/3] رفع الكود...
echo.
echo عندما يطلب منك:
echo - Username: qutibalwaabi
echo - Password: الصق الـ Token هنا (ليس كلمة المرور!)
echo.
git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo ✅ تم رفع الكود بنجاح!
    echo.
    echo الخطوات التالية:
    echo 1. افتح: https://github.com/qutibalwaabi/aldafary-app/actions
    echo 2. اضغط على "Build iOS"
    echo 3. اضغط "Run workflow"
    echo.
    start https://github.com/qutibalwaabi/aldafary-app/actions
) else (
    echo.
    echo ⚠️  قد تكون المشكلة في Token
    echo تأكد من:
    echo - أن Token لديه صلاحية repo
    echo - أنك استخدمت Token ككلمة مرور (ليس كلمة مرور GitHub)
)

pause

