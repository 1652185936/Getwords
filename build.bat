@echo off
REM Build the GetWords desktop app (Windows).
REM Produces dist\GetWords.exe

cd /d "%~dp0"

echo ^>^> Installing dependencies...
python -m pip install -r requirements.txt -r requirements-desktop.txt
if errorlevel 1 goto :error

echo ^>^> Building with PyInstaller...
python -m PyInstaller getwords.spec --noconfirm --clean
if errorlevel 1 goto :error

echo.
echo ^>^> Done. Your app is here:
echo    %cd%\dist\GetWords.exe
echo.
echo    Double-click GetWords.exe to launch.
goto :eof

:error
echo.
echo Build failed. Make sure Python 3.9+ is installed and on your PATH.
exit /b 1
