# Como abrir o DREAVON no Windows

Use este guia quando o DREAVON não abrir sozinho com o Windows, ou quando você o tiver fechado pelo menu "Sair" da bandeja.

## 1. Veja se ele já está aberto
O DREAVON fecha para a **bandeja**, não some. Antes de abrir de novo:
1. Na barra de tarefas, clique na setinha **^** perto do relógio (ícones ocultos).
2. Se o ícone do DREAVON estiver lá, clique nele para mostrar o painel.
3. Ou aperte o atalho global **Ctrl+Shift+Alt+D**, se você não o trocou nas Configurações.

## 2. Abra pelo Menu Iniciar
1. Aperte a tecla **Windows**.
2. Digite **DREAVON**.
3. Aperte **Enter** ou clique em "DREAVON".

O painel abre em alguns segundos. Para deixar mais à mão, clique com o botão direito em "DREAVON" no Menu Iniciar e escolha **Fixar em Iniciar** ou **Fixar na barra de tarefas**.

## 3. Se o atalho "DREAVON" não aparecer no Menu Iniciar
Recrie o atalho:
1. Abra o **PowerShell** na pasta do projeto: no Explorador de Arquivos, abra a pasta do DREAVON, clique com o botão direito num espaço vazio e escolha **Abrir no Terminal**.
2. Se você atualizou o código desde a última vez, compile:
   ```powershell
   .\build-windows.ps1
   ```
3. Crie o atalho:
   ```powershell
   .\tools\install-local.ps1
   ```
4. Volte ao passo 2 deste guia.

Se o Qt estiver instalado em outra pasta, informe-a: `.\tools\install-local.ps1 -QtDir "D:\Qt\6.11.3\msvc2022_64"`, ou defina a variável de ambiente `QT_DIR`.

## 4. Abrir direto pelo PowerShell (sem atalho)
Na pasta do projeto:
```powershell
.\build-windows.ps1 -Run
```
Isso compila, se for preciso, e abre o DREAVON. É o mesmo app; a diferença é que, sem o atalho do Menu Iniciar, as notificações podem aparecer com o nome do Qt em vez de "DREAVON".

## 5. Ligar (ou desligar) o início com o Windows
Escolha uma das formas:
- **No próprio DREAVON:** Configurações (menu da bandeja) > **Geral** > **Inicialização** > "Iniciar com o Windows". Vale na hora.
- **Pelo PowerShell**, na pasta do projeto:
  ```powershell
  .\tools\install-local.ps1 -IniciarComWindows     # liga
  .\tools\install-local.ps1 -NaoIniciarComWindows  # desliga
  ```
- **Pelo Windows:** Configurações > **Aplicativos** > **Inicialização** > "DREAVON" (liga e desliga sem apagar).

Com o início ligado, o DREAVON abre **só na bandeja**, sem mostrar a janela. Use o ícone da bandeja ou o atalho global para ver o painel.

## 6. Se nada abrir
| O que acontece | O que fazer |
| --- | --- |
| Clico no atalho e nada aparece | Veja a bandeja (passo 1): ele pode ter aberto escondido. Se não estiver lá, rode `.\build-windows.ps1 -Run` na pasta do projeto e leia as mensagens de erro na tela |
| Aparece "Não encontrado: …" ao rodar o `install-local.ps1` | Compile antes com `.\build-windows.ps1`, ou informe a pasta do Qt com `-QtDir` |
| Mudei a pasta do projeto ou do Qt | Rode `.\tools\install-local.ps1` de novo: ele recria o atalho com os caminhos novos. Com o início com o Windows ligado, rode também com `-IniciarComWindows` |
| O atalho global não responde | Outro app pode ter pegado a combinação. Veja a situação em Configurações > Geral > Atalho global |
| O Windows bloqueia a abertura (Controle Inteligente de Aplicativos) | Abra sempre pelo atalho ou pelo `build-windows.ps1 -Run`: os dois usam o `qml.exe` do Qt, que é assinado. Não tente abrir o `dreavon.exe` da pasta de build, porque ele não é assinado |

Para tirar o atalho, o registro do nome nas notificações e o início com o Windows, rode `.\tools\uninstall-local.ps1`. Suas configurações, lembretes e a chave da API não são apagados.
