@echo off
chcp 65001 >nul
echo ========================================
echo رفع المشروع باستخدام حساب GitHub في Cursor
echo ========================================
echo.

echo [1/6] التحقق من إعدادات Git الحالية...
git config user.name >nul 2>&1
if %errorlevel% equ 0 (
    echo    تم العثور على إعدادات Git موجودة
    git config user.name
    git config user.email
) else (
    echo    لا توجد إعدادات - سيتم استخدام القيم الافتراضية
    git config user.name "qutibalwaabi"
    git config user.email "qutibalwaabi@users.noreply.github.com"
)
echo Done!

echo.
echo [2/6] إضافة/تحديث remote...
git remote remove origin >nul 2>&1
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
git branch -M main >nul 2>&1
if %errorlevel% neq 0 (
    git checkout -b main >nul 2>&1
)
echo Done!

echo.
echo [6/6] الدفع إلى GitHub...
echo.
echo ⚠️  إذا طُلب منك تسجيل الدخول:
echo    - استخدم حساب GitHub المسجل في Cursor
echo    - أو استخدم Personal Access Token ككلمة مرور
echo.
git push -u origin main

echo.
echo ========================================
if %errorlevel% equ 0 (
    echo ✅ SUCCESS! تم رفع الكود بنجاح
    echo.
    echo 📋 الخطوات التالية:
    echo    1. افتح: https://github.com/qutibalwaabi/aldafary-app/actions
    echo    2. اضغط على "Build iOS"
    echo    3. اضغط "Run workflow"
    echo    4. انتظر 5-10 دقائق
    echo    5. حمّل ملف .ipa من Artifacts
    echo.
    start https://github.com/qutibalwaabi/aldafary-app/actions
) else (
    echo ❌ قد تحتاج إلى تسجيل الدخول
    echo.
    echo 💡 نصيحة: استخدم Source Control في Cursor:
    echo    1. اضغط على أيقونة Git في الشريط الجانبي
    echo    2. اضغط على "..." واختر "Push"
    echo    3. أو استخدم Command Palette (Ctrl+Shift+P)
    echo       واكتب "Git: Push"
)
echo ========================================
pause

