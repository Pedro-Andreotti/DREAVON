# Compila o plugin nativo no Windows (MSVC + Qt 6 + CMake + Ninja).
# Uso: .\build-windows.ps1 [-Config Release|Debug] [-QtDir C:\Qt\6.11.3\msvc2022_64] [-Run]
# Resultado: package\contents\ui\bridge\plasdriaplugin.dll e build-windows-<config>\dreavon.exe
# -Run abre o DREAVON depois de compilar.
param(
    [ValidateSet('Release', 'Debug')] [string]$Config = 'Release',
    [string]$QtDir = $(if ($env:QT_DIR) { $env:QT_DIR } else { 'C:\Qt\6.11.3\msvc2022_64' }),
    [switch]$Run
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not (Test-Path "$QtDir\lib\cmake\Qt6")) { throw "Qt 6 não encontrado em $QtDir. Use -QtDir ou a variável QT_DIR." }

# Carrega o ambiente do MSVC (cl, link, Windows SDK) a partir do vcvars64.bat.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual Studio / Build Tools com C++ não encontrado.' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$env:PATH = "$(Split-Path $vswhere);$env:PATH"  # o vcvars64.bat procura o vswhere no PATH
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
}
if (-not $env:WindowsSdkDir) { throw 'Windows SDK não encontrado. Instale pelo Visual Studio Installer (componente "SDK do Windows 11").' }

# CMake e Ninja instalados pelo winget podem ainda não estar no PATH desta sessão.
foreach ($dir in @("$env:ProgramFiles\CMake\bin", "$env:LOCALAPPDATA\Microsoft\WinGet\Links")) {
    if ((Test-Path $dir) -and ($env:PATH -notlike "*$dir*")) { $env:PATH = "$dir;$env:PATH" }
}

$build = Join-Path $root "build-windows-$($Config.ToLower())"
cmake -S $root -B $build -G Ninja "-DCMAKE_BUILD_TYPE=$Config" "-DCMAKE_PREFIX_PATH=$QtDir"
if ($LASTEXITCODE) { exit $LASTEXITCODE }
cmake --build $build
if ($LASTEXITCODE) { exit $LASTEXITCODE }
Write-Host "Plugin gerado em $root\package\contents\ui\bridge"
if ($Run) {
    # O Controle Inteligente de Aplicativos do Windows bloqueia o dreavon.exe (sem assinatura);
    # por isso o DREAVON abre pelo qml.exe do Qt, que é assinado.
    $env:PATH = "$QtDir\bin;$env:PATH"  # DLLs do Qt
    Start-Process -FilePath "$QtDir\bin\qml.exe" -ArgumentList @(
        '--apptype', 'widget', '-I', "`"$root\windows\qml`"", "`"$root\windows\dreavon.qml`"")
}
