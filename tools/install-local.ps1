# Uso local do DREAVON no Windows, por usuário e sem administrador (sem instalador nem assinatura).
# O app continua abrindo pelo qml.exe assinado do Qt, como o build-windows.ps1 -Run, porque o Controle
# Inteligente de Aplicativos bloqueia o dreavon.exe sem assinatura. Este script cria:
#   1. o atalho "DREAVON" no Menu Iniciar do usuário, com o ícone do app e o AppUserModelID
#      "DREAVON.Desktop" gravado no atalho (nome e ícone nas notificações e na barra de tarefas);
#   2. o registro desse AppUserModelID só no usuário (HKCU\Software\Classes\AppUserModelId);
#   3. (opcional) o início com o Windows, pelo valor "DREAVON" em HKCU\...\Run, aberto na bandeja.
# Nada de serviço, tarefa agendada ou chave de sistema. Desfazer: tools\uninstall-local.ps1.
#
# Uso: .\tools\install-local.ps1 [-QtDir C:\Qt\6.11.3\msvc2022_64] [-IniciarComWindows | -NaoIniciarComWindows]
# Sem nenhum dos dois, o início com o Windows fica como está (desligado na primeira vez).
# Compile antes com .\build-windows.ps1. O caminho do repositório é o da pasta deste script.
param(
    [string]$QtDir = $(if ($env:QT_DIR) { $env:QT_DIR } else { 'C:\Qt\6.11.3\msvc2022_64' }),
    [switch]$IniciarComWindows,
    [switch]$NaoIniciarComWindows
)
$ErrorActionPreference = 'Stop'
if ($IniciarComWindows -and $NaoIniciarComWindows) { throw 'Use só um: -IniciarComWindows ou -NaoIniciarComWindows.' }

$root = (Resolve-Path "$PSScriptRoot\..").Path
$aumid = 'DREAVON.Desktop'
$qml = Join-Path $QtDir 'bin\qml.exe'
$entry = Join-Path $root 'windows\dreavon.qml'
$imports = Join-Path $root 'windows\qml'
$icon = Join-Path $root 'package\contents\ui\assets\dreavon.ico'
$iconPng = Join-Path $root 'package\contents\ui\assets\icon.png'
foreach ($f in @($qml, $entry, $icon, (Join-Path $root 'package\contents\ui\bridge\dreavonplugin.dll'),
                 (Join-Path $imports 'org\kde\kirigami\kirigamishim.dll'))) {
    if (-not (Test-Path $f)) { throw "Não encontrado: $f. Confira -QtDir (ou QT_DIR) e compile com .\build-windows.ps1." }
}
$arguments = "--apptype widget -I `"$imports`" `"$entry`""

# Atalho com AppUserModelID: o WScript.Shell não grava essa propriedade, então usa a interface COM
# do Windows (IShellLinkW + IPropertyStore), compilada em memória.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace DreavonLocal {
    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellLinkW {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder f, int cch, IntPtr fd, uint flags);
        void GetIDList(out IntPtr pidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder s, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string s);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder s, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string s);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder s, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string s);
        void GetHotkey(out short k);
        void SetHotkey(short k);
        void GetShowCmd(out int c);
        void SetShowCmd(int c);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder s, int cch, out int i);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string s, int i);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string s, uint r);
        void Resolve(IntPtr hwnd, uint flags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string s);
    }
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct PropertyKey { public Guid fmtid; public uint pid; }
    [StructLayout(LayoutKind.Explicit, Size = 16)]
    struct PropVariant { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p; }
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore {
        void GetCount(out uint c);
        void GetAt(uint i, out PropertyKey k);
        void GetValue(ref PropertyKey k, out PropVariant v);
        void SetValue(ref PropertyKey k, ref PropVariant v);
        void Commit();
    }
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")] class CShellLink {}

    public static class Shortcut {
        // PKEY_AppUserModel_ID
        static PropertyKey AppIdKey = new PropertyKey { fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5 };
        [DllImport("ole32.dll")] static extern int PropVariantClear(ref PropVariant v);

        public static void Create(string lnk, string target, string args, string workDir, string icon, string desc, string appId, int showCmd) {
            var link = (IShellLinkW)new CShellLink();
            link.SetPath(target);
            link.SetArguments(args);
            link.SetWorkingDirectory(workDir);
            link.SetIconLocation(icon, 0);
            link.SetDescription(desc);
            link.SetShowCmd(showCmd);
            var store = (IPropertyStore)link;
            var key = AppIdKey;
            var value = new PropVariant { vt = 31 /* VT_LPWSTR */, p = Marshal.StringToCoTaskMemUni(appId) };
            store.SetValue(ref key, ref value);
            store.Commit();
            PropVariantClear(ref value);
            ((IPersistFile)link).Save(lnk, true);
            Marshal.FinalReleaseComObject(link);
        }
    }
}
'@

# 1. Atalho no Menu Iniciar (pasta Programas do usuário). Janela "minimizada": o qml.exe é um programa
#    de console, e o console abre minimizado; o plugin do DREAVON o esconde logo ao carregar.
$programs = [Environment]::GetFolderPath('Programs')
$lnk = Join-Path $programs 'DREAVON.lnk'
[DreavonLocal.Shortcut]::Create($lnk, $qml, $arguments, $root, $icon, 'DREAVON', $aumid, 7)
# Confere pela leitura do próprio Shell do Windows.
$readBack = (New-Object -ComObject Shell.Application).Namespace($programs).ParseName('DREAVON.lnk').ExtendedProperty('System.AppUserModel.ID')
if ($readBack -ne $aumid) { throw "O atalho foi criado, mas o AppUserModelID não ficou gravado (lido: '$readBack')." }
Write-Host "Atalho criado no Menu Iniciar: DREAVON (AppUserModelID $aumid)"

# 2. Registro do AppUserModelID só no usuário: nome e ícone mostrados pelo Windows nas notificações.
$appKey = "HKCU:\Software\Classes\AppUserModelId\$aumid"
New-Item -Path $appKey -Force | Out-Null
New-ItemProperty -Path $appKey -Name 'DisplayName' -Value 'DREAVON' -PropertyType String -Force | Out-Null
if (Test-Path $iconPng) { New-ItemProperty -Path $appKey -Name 'IconUri' -Value $iconPng -PropertyType String -Force | Out-Null }
# Marca de origem: o tools\uninstall-local.ps1 só apaga a chave se ela tiver esta marca.
New-ItemProperty -Path $appKey -Name 'DreavonLocal' -Value 'tools/install-local.ps1' -PropertyType String -Force | Out-Null
Write-Host "AppUserModelID registrado no usuário: $aumid"

# 3. Início com o Windows (chave Run do usuário), abrindo só na bandeja.
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if ($IniciarComWindows) {
    New-ItemProperty -Path $runKey -Name 'DREAVON' -Value "`"$qml`" $arguments -- --bandeja" -PropertyType String -Force | Out-Null
    Write-Host 'Início com o Windows: ligado (na bandeja).'
} elseif ($NaoIniciarComWindows) {
    $current = (Get-ItemProperty -Path $runKey -Name 'DREAVON' -ErrorAction SilentlyContinue).DREAVON
    if ($current -and $current -like '*dreavon.qml*') { Remove-ItemProperty -Path $runKey -Name 'DREAVON' }
    Write-Host 'Início com o Windows: desligado.'
} else {
    $on = [bool](Get-ItemProperty -Path $runKey -Name 'DREAVON' -ErrorAction SilentlyContinue)
    Write-Host "Início com o Windows: $(if ($on) { 'ligado' } else { 'desligado' }) (sem mudança; use -IniciarComWindows ou -NaoIniciarComWindows)."
}
Write-Host 'Pronto. Abra o DREAVON pelo Menu Iniciar. Se ele já estiver aberto, saia pela bandeja e abra de novo pelo atalho.'
