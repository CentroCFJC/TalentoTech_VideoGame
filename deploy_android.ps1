# deploy_android.ps1
# Exporta el APK de Android (debug) e instala en el celular conectado por USB.
# Uso:
#   .\deploy_android.ps1
#   (si PowerShell bloquea scripts:  powershell -ExecutionPolicy Bypass -File .\deploy_android.ps1)

$ErrorActionPreference = "Stop"

$GodotConsole = "D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$ProjectDir   = "D:\TalentoTech_VideoGame"
$ApkPath      = Join-Path $ProjectDir "build\android\Infinite Runner.apk"
$PackageName  = "com.talentotech.infiniterunner"

Write-Host ""
Write-Host "=== 1/3 Exportando APK (debug) ===" -ForegroundColor Cyan
& $GodotConsole --headless --path $ProjectDir --export-debug "Android" $ApkPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: la exportación falló (código $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $ApkPath)) {
    Write-Host "Error: no se generó el APK en $ApkPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== 2/3 Verificando dispositivo ===" -ForegroundColor Cyan
$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    Write-Host "Error: no se encontró 'adb' en el PATH." -ForegroundColor Red
    exit 1
}
$deviceLines = (& adb devices) | Select-String -Pattern "\s+device\s*$"
if (-not $deviceLines) {
    Write-Host "Error: no hay ningún dispositivo Android conectado y autorizado." -ForegroundColor Red
    Write-Host "Conecta el celular por USB, activa 'Depuración USB' y acepta el diálogo de autorización." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== 3/3 Instalando y lanzando ===" -ForegroundColor Cyan
& adb install -r "$ApkPath"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: adb install falló (código $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

& adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null

Write-Host ""
Write-Host "Listo. APK instalado y app lanzada." -ForegroundColor Green
