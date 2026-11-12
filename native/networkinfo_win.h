#pragma once

// Leituras de rede no Windows para o NetworkClient (passo 5). Só consultas: nada aqui liga, desliga
// ou reconfigura adaptadores. Valor indisponível: -1 (números) ou texto vazio.

#include <QList>
#include <QString>
#include <QtGlobal>

namespace NetworkInfoWin {

// Contadores de bytes de uma interface física ativa (GetIfTable2).
struct Counter {
    quint64 luid = 0;   // NET_LUID da interface, só para casar duas leituras seguidas
    quint64 rx = 0, tx = 0;
};

// Interfaces contadas: de hardware (HardwareInterface), que não são filtro (FilterInterface),
// ligadas (OperStatus up) e do tipo Ethernet, Wi-Fi ou banda larga móvel. Ficam de fora loopback,
// VPN/túnel, adaptadores virtuais (Hyper-V, WSL, VirtualBox, TAP, Radmin...), pontes e os
// "filtros" que o Windows empilha sobre cada placa, que repetiriam os mesmos bytes.
// Falso se a tabela não pôde ser lida (indisponível); verdadeiro com lista vazia = nenhuma ativa.
bool counters(QList<Counter> *out, int *skipped = nullptr);

// Conexão principal: a interface da melhor rota para um destino público (GetBestInterfaceEx).
struct Connection {
    bool valid = false;     // há rota para a internet por alguma interface
    QString name;           // Wi-Fi: SSID; demais: nome amigável do adaptador ("Ethernet")
    QString type;           // "Wi-Fi", "Cabo", "Móvel", "VPN" ou "Rede" (mesmos rótulos do Linux)
    QString address;        // primeiro IPv4 da interface
    int strength = -1;      // qualidade do sinal do Wi-Fi (0-100) ou -1
    QString hint;           // por que nome/sinal do Wi-Fi faltam (permissão de localização), ou vazio
    quint64 luid = 0;
};
Connection primary();

}
