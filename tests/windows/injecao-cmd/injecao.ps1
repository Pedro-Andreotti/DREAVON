# Testa se o texto do chat e os argumentos chegam aos CLIs sem passar pelo cmd.exe (passo 3, item 3).
# Uso: .\tests\windows\injecao-cmd\injecao.ps1 [-QtDir C:\Qt\6.11.3\msvc2022_64]
# Precisa do plugin compilado (.\build-windows.ps1), de python e de node no PATH.
# Nao usa rede nem CLIs de verdade: codex.cmd e npmlike\fakecli.cmd sao falsos e so registram o que recebem.
# (Mensagens sem acento: o Windows PowerShell 5.1 le .ps1 sem BOM como ANSI.)
param([string]$QtDir = $(if ($env:QT_DIR) { $env:QT_DIR } else { 'C:\Qt\6.11.3\msvc2022_64' }))
$here = $PSScriptRoot
$env:PATH = "$QtDir\bin;$env:PATH"
$env:QT_FORCE_STDERR_LOGGING = '1'; $env:QT_QPA_PLATFORM = 'offscreen'
$image = Join-Path $here 'foto & echo INJETADO %PATH% !.png'
Copy-Item -LiteralPath (Join-Path $here '..\..\..\package\contents\ui\assets\mark.png') -Destination $image -Force
$failed = 0

function Run($scenario) {
    Remove-Item -LiteralPath (Join-Path $here 'calls.log'), (Join-Path $here 'pwned.txt') -ErrorAction SilentlyContinue
    $out = (& "$QtDir\bin\qml.exe" (Join-Path $here 'injecao.qml') -- $scenario 2>&1 | Out-String)
    $log = Get-Content -LiteralPath (Join-Path $here 'calls.log') -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    return @{ out = $out; log = $log; pwned = Test-Path -LiteralPath (Join-Path $here 'pwned.txt') }
}
function Check($name, $ok) {
    if ($ok) { Write-Host "ok      $name" } else { Write-Host "FALHOU  $name"; $script:failed++ }
}

$a = Run 'A'
$entryA = if ($a.log) { $a.log | ConvertFrom-Json } else { $null }
Check 'A: o .cmd foi executado' ($null -ne $entryA)
Check 'A: a mensagem chegou so pelo stdin' ($entryA -and $entryA.stdin -like '*echo INJETADO*' -and -not ($entryA.argv -match 'INJETADO'))
Check 'A: nada foi injetado' (-not $a.pwned)

$b = Run 'B'
Check 'B: o .cmd nao foi executado' (-not $b.log)
Check 'B: mensagem de seguranca' ($b.out -match 'Por seguran')
Check 'B: o chat nao ficou travado' ($b.out -match 'BUSY false')
Check 'B: nada foi injetado' (-not $b.pwned)

$c = Run 'C'
$entryC = if ($c.log) { $c.log | ConvertFrom-Json } else { $null }
Check 'C: o shim do npm virou node + script' ($entryC -and $entryC.via -eq 'node')
Check 'C: a mensagem chegou intacta como argumento' ($entryC -and ($entryC.argv[-1] -like 'teste "aspas" & echo INJETADO*linha 2 & del `*.`*'))
Check 'C: nada foi injetado' (-not $c.pwned)

Remove-Item -LiteralPath $image, (Join-Path $here 'calls.log') -ErrorAction SilentlyContinue
if ($failed) { Write-Host "$failed verificacao(oes) falharam."; exit 1 } else { Write-Host 'Todos os cenarios passaram.' }
