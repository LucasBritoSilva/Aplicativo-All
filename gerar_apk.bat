@echo off
setlocal
rem ==================================================================
rem  Gera o APK do All e copia para ..\entrega\All.apk
rem
rem  Se android\key.properties existir, o APK sai assinado com a chave
rem  de producao (ver docs\PUBLICACAO.md); senao, com a chave de debug.
rem
rem  A pasta do projeto pode ter acentos, o que quebra algumas
rem  ferramentas do Flutter no Windows. Por isso o script cria uma
rem  unidade virtual temporaria (ex.: P:) apontando para a pasta acima
rem  deste arquivo, gera o APK por ela e remove a unidade no final.
rem ==================================================================

set "PROJ=%~dp0"
set "PROJ=%PROJ:~0,-1%"
for %%I in ("%PROJ%\..") do set "ROOT=%%~fI"
for %%I in ("%PROJ%") do set "NAME=%%~nxI"

where flutter >nul 2>nul
if errorlevel 1 (
  echo O comando flutter nao foi encontrado.
  echo Feche esta janela, abra de novo e tente outra vez.
  pause
  exit /b 1
)

set "DRV="
for %%L in (P Q R S T U V W Y Z) do (
  if not defined DRV if not exist %%L:\ set "DRV=%%L:"
)
if not defined DRV (
  echo Nenhuma letra de unidade livre para a unidade virtual.
  pause
  exit /b 1
)

subst %DRV% "%ROOT%"
if errorlevel 1 (
  echo Nao foi possivel criar a unidade virtual %DRV%.
  pause
  exit /b 1
)

pushd %DRV%\%NAME%
echo.
echo === Baixando dependencias ===
call flutter pub get
echo.
echo === Gerando o codigo do banco ===
call dart run build_runner build --delete-conflicting-outputs --force-jit
echo.
echo === Gerando o APK (pode levar varios minutos na primeira vez) ===
call flutter build apk --release
set "ERR=%ERRORLEVEL%"

if "%ERR%"=="0" (
  if not exist "%DRV%\entrega" mkdir "%DRV%\entrega"
  copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%DRV%\entrega\All.apk" >nul
  echo.
  echo ==============================================================
  echo  Pronto! APK gerado em:
  echo  %ROOT%\entrega\All.apk
  echo ==============================================================
) else (
  echo.
  echo O APK NAO foi gerado. Veja as mensagens acima.
)

popd
subst %DRV% /d
echo.
pause
exit /b %ERR%
