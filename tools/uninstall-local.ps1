# Desfaz o tools\install-local.ps1: remove só o que ele criou.
#   - o atalho "DREAVON" do Menu Iniciar (só se apontar para o qml.exe com windows\dreavon.qml);
#   - o registro do AppUserModelID "DREAVON.Desktop" no usuário (só se tiver a marca do script);
#   - o início com o Windows (valor "DREAVON" da chave Run, só se for o comando do DREAVON).
# NÃO apaga as configurações, o histórico, o cache nem a chave da API do Gerenciador de Credenciais:
# só mostra onde eles ficam, para você decidir.
# Uso: .\tools\uninstall-local.ps1
$ErrorActionPreference = 'Stop'

$lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'DREAVON.lnk'
if (Test-Path $lnk) {
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    if ($shortcut.TargetPath -like '*\qml.exe' -and $shortcut.Arguments -like '*dreavon.qml*') {
        Remove-Item $lnk -Force
        Write-Host 'Atalho do Menu Iniciar removido.'
    } else {
        Write-Host 'Há um atalho "DREAVON" no Menu Iniciar que não foi criado por este script; ficou como está.'
    }
} else { Write-Host 'Atalho do Menu Iniciar: não existia.' }

$appKey = 'HKCU:\Software\Classes\AppUserModelId\DREAVON.Desktop'
if (Test-Path $appKey) {
    if ((Get-ItemProperty $appKey -ErrorAction SilentlyContinue).DreavonLocal) {
        Remove-Item $appKey -Recurse -Force
        Write-Host 'Registro do AppUserModelID removido.'
    } else { Write-Host 'O registro DREAVON.Desktop não tem a marca do script; ficou como está.' }
} else { Write-Host 'Registro do AppUserModelID: não existia.' }

$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$current = (Get-ItemProperty -Path $runKey -Name 'DREAVON' -ErrorAction SilentlyContinue).DREAVON
if ($current -and $current -like '*dreavon.qml*') {
    Remove-ItemProperty -Path $runKey -Name 'DREAVON'
    Write-Host 'Início com o Windows removido.'
} elseif ($current) { Write-Host 'O valor "DREAVON" da chave Run não é o comando do DREAVON; ficou como está.' }
else { Write-Host 'Início com o Windows: não estava ligado.' }

Write-Host ''
Write-Host 'Continuam no seu usuário (nada disso foi apagado):'
Write-Host "  - Configurações e lembretes: $env:APPDATA\DREAVON"
Write-Host "  - Histórico de conversas e cache: $env:LOCALAPPDATA\dreavon e $env:LOCALAPPDATA\cache\dreavon"
Write-Host '  - Chave da API: Gerenciador de Credenciais do Windows, item "DREAVON/customApiKey"'
Write-Host '    (para apagar: Painel de Controle > Gerenciador de Credenciais > Credenciais do Windows).'
