#pragma once

// Leituras do sistema no Windows para o DashboardClient (passo 4). Todas são leves (APIs do Win32,
// registro e contadores PDH já abertos), sem WMI e sem abrir processos, e podem rodar a cada ciclo.
// Valor indisponível: -1 (números) ou texto vazio, para a interface mostrar "—" e nunca 0%.

#include <QString>
#include <QtGlobal>

namespace SystemInfoWin {

// Tempos acumulados da CPU (GetSystemTimes). O uso é a diferença entre duas leituras.
bool cpuTimes(quint64 *idle, quint64 *total);

// Memória física em bytes (GlobalMemoryStatusEx): total e disponível.
bool memory(quint64 *total, quint64 *available);

// Arquivo de paginação ("swap") em bytes: tamanho alocado e em uso. Falso se não houver.
bool pageFile(quint64 *total, quint64 *used);

qint64 uptimeSeconds();        // GetTickCount64
int processCount();            // GetPerformanceInfo; -1 se falhar
QString cpuModel();            // registro: ProcessorNameString
QString productName();         // registro: BIOS\SystemProductName (pode ser genérico)
QString windowsVersion();      // ex.: "compilação 26300.1234" (só a compilação)

// Uso da GPU em % pelos contadores PDH "GPU Engine", como o Gerenciador de Tarefas: soma por
// adaptador e tipo de mecanismo (3D, cópia, vídeo…) e pega o maior. Vale para qualquer GPU
// (integrada e dedicada). -1 se os contadores não existirem.
double gpuUsage();

// Temperatura (°C) do disco que contém o Windows, pela consulta do próprio driver de armazenamento
// (IOCTL_STORAGE_QUERY_PROPERTY / StorageDeviceTemperatureProperty), sem administrador.
// Guardada por 10 s para não consultar o disco a cada ciclo. -1 se o disco não informar.
double systemDiskTemperature();

struct Power {
    bool valid = false;        // GetSystemPowerStatus respondeu
    bool hasBattery = false;   // falso em PC de mesa (BatteryFlag 128)
    int percent = -1;          // -1 = desconhecido
    bool onAc = false;
    bool charging = false;
    qint64 secondsLeft = -1;   // -1 = desconhecido ou na tomada
};
Power power();

}
