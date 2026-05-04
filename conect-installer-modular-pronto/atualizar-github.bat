@echo off
cd /d "%~dp0"
git add .
git commit -m "Atualizar templates conect installer"
git push origin main
pause
