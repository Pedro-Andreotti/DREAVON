# 05 — Cartão "Dispositivos" no Windows

Data: 2026-11-11 · Branch: `feat/dispositivos-windows`

## Causa confirmada
O cartão mostrava só o próprio notebook porque a parte de periféricos **não estava implementada** no Windows. Não era defeito:
- `requestBatteries()` (`native/dashboardclient.cpp`), sem D-Bus, só limpava `m_upowerDevices` e `m_bluetoothDevices` (`TODO(Windows)`): UPower e BlueZ não existem no Windows.
- A lista de USB, mouse e teclado lia `/sys/class/input` e `/sys/bus/usb/devices`. Esse trecho não tem `#ifdef` e roda no Windows, mas não acha nada.
- A regra do teclado "AULA F75" é do autor original e fica só no código do Linux; não foi copiada para o Windows.
- `peripheralDevices()` junta as listas, e o `ConnectionsCard.qml` mostra só quem informa bateria (`percent >= 0`), resumindo o resto em "N dispositivos sem bateria informada" (nomes na dica).
- Antes da mudança, no Windows: `usbDevices` = 0 e `peripheralDevices` = 1 (só o computador).

## O que esta máquina informa (rótulos genéricos)
- **Conectados:** fone Bluetooth (único pareado), fone/microfone USB, receptor sem fio Logitech (LIGHTSPEED), receptor sem fio genérico 2.4G e o teclado/touchpad internos do notebook.
- **Impressoras:** uma impressora de rede e duas virtuais (PDF e OneNote).
- **Dispositivos de software:** um dispositivo virtual do software da Logitech.
- **Nomes:** os mouses e teclados HID aparecem só com nomes genéricos ("Mouse compatível com HID", "Dispositivo de teclado HID"); o nome útil é o do receptor.
- **Bateria Bluetooth na propriedade `{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2`:** nenhum nó da máquina a tem. A chave não é documentada pela Microsoft (não está no `devpkey.h`); várias ferramentas a usam, e ela fica no nó Hands-Free (enumerador `BTHHFENUM`) de fones clássicos.
- **Configurações mostra a bateria do fone Bluetooth** (confirmado pelo usuário). O valor fica em outro lugar, não alcançado neste passo (ver "Fora do escopo").
- **Receptores de fabricante** (Logitech LIGHTSPEED e o genérico 2.4G) não informam bateria ao Windows: usam protocolo próprio (HID++ no caso da Logitech). Confirmado.
- **BLE:** nenhum aparelho Bluetooth LE conectado; o caminho GATT (serviço de bateria 0x180F) não pôde ser testado.
- **Consulta de "pontos de associação" (AEP) sem filtro:** também traz aparelhos de vizinhos descobertos pela rede e pelo Bluetooth (TVs, ar-condicionado etc.), e os valores de conexão e bateria vieram vazios com o fone desligado. Os nomes desses aparelhos não foram registrados.

## O que foi implementado
| Arquivo | Mudança | Motivo |
| --- | --- | --- |
| `native/systeminfo_win.h/.cpp` | `peripherals()`: lista os nós presentes (`CM_Get_Device_ID_List` com `CM_GETIDLIST_FILTER_PRESENT`), agrupa por contêiner (`DEVPKEY_Device_ContainerId`) e lê nome, categoria, conectado e se é de rede (`DevGetObjectProperties`) | São os mesmos "aparelhos" que Configurações lista, com API documentada, sem administrador e sem WinRT |
| `native/dashboardclient.cpp` | `requestBatteries()` no Windows (`#elif defined(Q_OS_WIN)`): preenche a lista a cada 15 s, não a cada 5 s, e só avisa a interface se mudou | Leitura leve; o caminho do Linux (D-Bus) não mudou |
| `CMakeLists.txt` | `cfgmgr32` só no `WIN32` | Biblioteca do sistema (SDK do Windows), não é dependência nova de terceiros |

Regras da lista:
- **Ficam de fora:**
  - o contêiner do próprio computador (componentes internos);
  - aparelhos de rede (`IsNetworkDevice`);
  - desconectados (`IsConnected`);
  - contêineres sem nenhum nó em barramento físico (USB, USBSTOR, BTHENUM, BTHLE, BTHLEDEVICE, BTHHFENUM). Isso tira impressoras virtuais e dispositivos de software.
- **Tipo** pela categoria documentada do contêiner: "Audio" → Fone; "Communication.Phone" → Celular; só "Input.Mouse" → Mouse; só "Input.Keyboard" → Teclado. Receptor com mouse e teclado fica sem tipo.
- **Nome** em forma de referência a recurso (`@arquivo.inf,%chave%;Texto`): usa o texto depois do `;`.
- **Bateria:**
  - a propriedade não documentada `{104EA319…} 2` de qualquer nó do contêiner;
  - senão, `System.Devices.BatteryLife` do contêiner (documentada no `propkey.h`);
  - senão, `-1`, e o aparelho vai para a linha de resumo, nunca 0%.
- `DevGetObjectProperties` está no `cfgmgr32.dll` mas não no `cfgmgr32.lib` (só no `onecore.lib`); por isso é carregada com `GetProcAddress`.
- **QML:** não precisou mudar. O cartão já trata `-1` como "sem bateria informada".

## DREAVON x Windows
| Tipo | No DREAVON | Bateria | Comparação |
| --- | --- | --- | --- |
| Notebook (bateria do sistema) | aparece | 100%, igual ao Windows | igual |
| Fone Bluetooth | aparece quando conectado (tipo Fone) e some ao desconectar | **indisponível no DREAVON; o Windows mostra %** | **diferente** (ver "Fora do escopo") |
| Fone/microfone USB | aparece (tipo Fone) | sem bateria (é com fio) | aparece |
| Receptor sem fio Logitech | aparece, sem tipo (mouse e teclado) | indisponível (protocolo próprio) | aparece |
| Receptor sem fio genérico 2.4G | aparece, sem tipo | indisponível | aparece |
| Impressoras de rede e virtuais | não aparecem (filtradas de propósito) | — | o Windows as lista em "Impressoras", não como periféricos |
| Pendrive | **não verificado** | — | nenhum foi conectado no teste |
| Celular | **não verificado** | — | nenhum conectado |

No cartão: o notebook com 100% e "4 dispositivos sem bateria informada" (nomes na dica).

## Conectar e desconectar (monitor de 150 s)
- O fone USB saiu da lista e voltou cerca de 15 s depois.
- O fone Bluetooth saiu da lista ao ser desconectado. A atualização leva até 15 s.
- A reconexão do fone Bluetooth não foi capturada: o monitor terminou antes.

## Fora do escopo (decisão pendente)
| Opção | O que dá | API | Complexidade | Administrador / WinRT / dependência |
| --- | --- | --- | --- | --- |
| Bateria do fone Bluetooth como em Configurações | % do fone | provavelmente propriedades dos "pontos de associação" (AEP) por `DevGetObjects` com filtro e o fone conectado, ou WinRT `Windows.Devices.Enumeration` | média a alta; o teste sem filtro devolveu valores vazios e aparelhos de vizinhos | não / talvez / não |
| Bateria de BLE pelo GATT (0x180F/0x2A19) | % de mouse, teclado e fone BLE | C++/WinRT `Windows.Devices.Bluetooth` | alta (assíncrono, WinRT num app Qt) | não / **sim** / C++/WinRT; sem aparelho BLE aqui para testar |
| Bateria de receptores Logitech | % de mouse e teclado Logitech | HID++ (protocolo próprio) ou o software da Logitech | alta | fora do alcance sem o software do fabricante; não recomendado |

## Não verificado
- Pendrive, celular e qualquer aparelho BLE.
- Reconexão do fone Bluetooth.
- A lista de Configurações > Bluetooth e dispositivos e do Gerenciador de Dispositivos lado a lado com o cartão (o usuário confirmou só a bateria do fone). A comparação acima usa o que as APIs do Windows informam.
- A propriedade `{104EA319…} 2` e o `System.Devices.BatteryLife` com algum aparelho que os informe (nenhum aqui).
- Linux (não testado nesta máquina; o código do Linux não mudou).

## Pendências
- Decidir o caminho da bateria do fone Bluetooth (AEP com filtro ou WinRT) e o do BLE.
- Atualizar ao detectar mudança (`CM_Register_Notification`) no lugar do intervalo de 15 s, se quiser resposta imediata.
- No Windows ainda roda, sem efeito, o trecho do Linux que lê `/sys/class/input` (acha 0 itens); pode ir para trás de `#ifndef Q_OS_WIN` numa limpeza futura.
