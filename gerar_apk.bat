@echo off
setlocal
rem ==================================================================
rem  Gera o APK debug do App Pessoal e copia para
rem  ..\entrega\app_pessoal-debug.apk
rem
rem  A pasta do projeto tem acentos ("Programacao" com cedilha e til),
rem  o que quebra algumas ferramentas do Flutter no Windows. Por isso o
rem  script cria uma unidade virtual temporaria (ex.: P:) apontando para
rem  a pasta acima deste arquivo, gera o APK por ela e remove a unidade
rem  no final. Nada fora do projeto e alterado.
rem ==================================================================

set "PROJ=%~dp0"
set "PROJ=%PROJ:~0,-1%"
for %%I in ("%PROJ%\..") do set "ROOT=%%~fI"

where flutter >nul 2>nul
if errorlevel 1 (
  echo O comando flutter nao foi encontrado.
  echo Feche esta janela, abra de novo e tente outra vez.
  echo Se continuar, veja PENDENCIAS.md, etapa a.
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

pushd %DRV%\app_pessoal
echo.
echo === Baixando dependencias ===
call flutter pub get
echo.
echo === Gerando o APK (pode levar varios minutos na primeira vez) ===
call flutter build apk --debug
set "ERR=%ERRORLEVEL%"

if "%ERR%"=="0" (
  if not exist "%DRV%\entrega" mkdir "%DRV%\entrega"
  copy /Y "build\app\outputs\flutter-apk\app-debug.apk" "%DRV%\entrega\app_pessoal-debug.apk" >nul
  echo.
  echo ==============================================================
  echo  Pronto! APK gerado em:
  echo  %ROOT%\entrega\app_pessoal-debug.apk
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
