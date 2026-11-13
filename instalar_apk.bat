@echo off
setlocal
rem ==================================================================
rem  Instala o ..\entrega\BrutAll.apk no celular conectado
rem  por cabo USB (com a Depuracao USB ativada). Gere antes com gerar_apk.bat.
rem ==================================================================

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  echo O programa adb nao foi encontrado em:
  echo %ADB%
  echo O Android SDK deveria estar em %LOCALAPPDATA%\Android\Sdk.
  pause
  exit /b 1
)

pushd "%~dp0..\entrega"
if not exist "BrutAll.apk" (
  echo O APK ainda nao existe na pasta entrega.
  echo Rode primeiro o gerar_apk.bat.
  popd
  pause
  exit /b 1
)

echo === Procurando o celular ===
"%ADB%" start-server >nul 2>nul
"%ADB%" devices
echo Se aparecer "unauthorized", olhe o celular e toque em Permitir.
echo Se nao aparecer nenhum aparelho, confira o cabo e a Depuracao USB.
echo.
echo === Instalando (o celular pode pedir confirmacao) ===
"%ADB%" install -r "BrutAll.apk"
set "ERR=%ERRORLEVEL%"
popd

echo.
if "%ERR%"=="0" (
  echo Pronto! Procure o icone "BrutAll" no celular.
) else (
  echo A instalacao NAO deu certo. Veja as mensagens acima.
)
pause
exit /b %ERR%
