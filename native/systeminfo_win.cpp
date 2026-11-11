#include "systeminfo_win.h"

#include <QSettings>
#include <qt_windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <psapi.h>
#include <winioctl.h>
#include <QHash>
#include <string>

namespace {
quint64 fileTimeValue(const FILETIME &t) { return (quint64(t.dwHighDateTime) << 32) | t.dwLowDateTime; }

QString registryString(const QString &key, const QString &name) {
    // QSettings lê o registro nativo; NativeFormat + caminho HKEY_LOCAL_MACHINE\... é só leitura aqui.
    return QSettings(key, QSettings::NativeFormat).value(name).toString().trimmed();
}

// Contador PDH com nome em inglês (vale em Windows de qualquer idioma). Aberto uma vez e reaproveitado.
class Counter {
public:
    explicit Counter(const wchar_t *path) {
        if (PdhOpenQueryW(nullptr, 0, &m_query) != ERROR_SUCCESS) { m_query = nullptr; return; }
        if (PdhAddEnglishCounterW(m_query, path, 0, &m_counter) != ERROR_SUCCESS) { PdhCloseQuery(m_query); m_query = nullptr; return; }
        PdhCollectQueryData(m_query);   // primeira coleta: contadores de taxa precisam de duas
    }
    ~Counter() { if (m_query) PdhCloseQuery(m_query); }
    bool valid() const { return m_query != nullptr; }
    // Valor atual (contador simples). -1 se não houver dado.
    double value() {
        if (!m_query || PdhCollectQueryData(m_query) != ERROR_SUCCESS) return -1;
        PDH_FMT_COUNTERVALUE v;
        if (PdhGetFormattedCounterValue(m_counter, PDH_FMT_DOUBLE, nullptr, &v) != ERROR_SUCCESS || v.CStatus != ERROR_SUCCESS) return -1;
        return v.doubleValue;
    }
private:
    PDH_HQUERY m_query = nullptr;
    PDH_HCOUNTER m_counter = nullptr;
};
}

namespace SystemInfoWin {

bool cpuTimes(quint64 *idle, quint64 *total) {
    FILETIME idleTime, kernelTime, userTime;
    if (!GetSystemTimes(&idleTime, &kernelTime, &userTime)) return false;
    *idle = fileTimeValue(idleTime);
    *total = fileTimeValue(kernelTime) + fileTimeValue(userTime);   // o tempo de kernel já inclui o ocioso
    return true;
}

bool memory(quint64 *total, quint64 *available) {
    MEMORYSTATUSEX status{};
    status.dwLength = sizeof(status);
    if (!GlobalMemoryStatusEx(&status)) return false;
    *total = status.ullTotalPhys;
    *available = status.ullAvailPhys;
    return true;
}

bool pageFile(quint64 *total, quint64 *used) {
    // ullTotalPageFile é o limite de commit (RAM + arquivos de paginação), não o "swap":
    // o tamanho dos arquivos de paginação é a diferença para a RAM. O uso vem do contador
    // "\Paging File(_Total)\% Usage", em porcentagem desse tamanho.
    MEMORYSTATUSEX status{};
    status.dwLength = sizeof(status);
    if (!GlobalMemoryStatusEx(&status) || status.ullTotalPageFile <= status.ullTotalPhys) return false;
    static Counter usage(L"\\Paging File(_Total)\\% Usage");
    const double percent = usage.value();
    if (percent < 0) return false;
    *total = status.ullTotalPageFile - status.ullTotalPhys;
    *used = quint64(double(*total) * qBound(0.0, percent, 100.0) / 100.0);
    return true;
}

qint64 uptimeSeconds() { return qint64(GetTickCount64() / 1000); }

int processCount() {
    PERFORMANCE_INFORMATION info{};
    info.cb = sizeof(info);
    return GetPerformanceInfo(&info, sizeof(info)) ? int(info.ProcessCount) : -1;
}

QString cpuModel() {
    return registryString(QStringLiteral("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0"),
                          QStringLiteral("ProcessorNameString"));
}

QString productName() {
    return registryString(QStringLiteral("HKEY_LOCAL_MACHINE\\HARDWARE\\DESCRIPTION\\System\\BIOS"), QStringLiteral("SystemProductName"));
}

QString windowsVersion() {
    // Só a compilação: o nome e a versão ("Windows 11 Version 25H2") já vêm do QSysInfo.
    QSettings reg(QStringLiteral("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion"), QSettings::NativeFormat);
    const QString build = reg.value(QStringLiteral("CurrentBuild")).toString();
    if (build.isEmpty()) return {};
    const QVariant ubr = reg.value(QStringLiteral("UBR"));
    return QStringLiteral("compilação ") + build + (ubr.isValid() ? "." + QString::number(ubr.toUInt()) : QString());
}

double gpuUsage() {
    // Contador de taxa com curinga: as instâncias (processo × adaptador × mecanismo) mudam a cada coleta.
    static PDH_HQUERY query = nullptr;
    static PDH_HCOUNTER counter = nullptr;
    static bool tried = false;
    if (!tried) {
        tried = true;
        if (PdhOpenQueryW(nullptr, 0, &query) != ERROR_SUCCESS) query = nullptr;
        else if (PdhAddEnglishCounterW(query, L"\\GPU Engine(*)\\Utilization Percentage", 0, &counter) != ERROR_SUCCESS) {
            PdhCloseQuery(query); query = nullptr;
        } else PdhCollectQueryData(query);
    }
    if (!query || PdhCollectQueryData(query) != ERROR_SUCCESS) return -1;
    DWORD size = 0, count = 0;
    if (PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, nullptr) != PDH_MORE_DATA || size == 0) return -1;
    QByteArray buffer(int(size), Qt::Uninitialized);
    auto *items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W *>(buffer.data());
    if (PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, items) != ERROR_SUCCESS) return -1;
    // Nome da instância: pid_<n>_luid_<a>_<b>_phys_<n>_eng_<n>_engtype_<tipo>
    QHash<QString, double> perEngine;
    for (DWORD i = 0; i < count; ++i) {
        if (items[i].FmtValue.CStatus != ERROR_SUCCESS) continue;
        const QString name = QString::fromWCharArray(items[i].szName);
        const int luid = name.indexOf(QLatin1String("luid_")), eng = name.indexOf(QLatin1String("_eng_")), type = name.indexOf(QLatin1String("engtype_"));
        if (luid < 0 || eng < 0 || type < 0) continue;
        perEngine[name.mid(luid, eng - luid) + name.mid(type)] += items[i].FmtValue.doubleValue;
    }
    double best = 0;
    for (double v : std::as_const(perEngine)) best = qMax(best, v);
    return qBound(0.0, best, 100.0);
}

double systemDiskTemperature() {
    static qint64 lastRead = -1;
    static double cached = -1;
    const qint64 now = qint64(GetTickCount64());
    if (lastRead >= 0 && now - lastRead < 10000) return cached;
    lastRead = now;
    cached = -1;
    // Disco físico do volume do Windows (normalmente C:). Acesso 0: só consultas, sem administrador.
    wchar_t windowsDir[MAX_PATH];
    if (!GetWindowsDirectoryW(windowsDir, MAX_PATH)) return cached;
    const std::wstring volume = std::wstring(L"\\\\.\\") + windowsDir[0] + L":";
    HANDLE vol = CreateFileW(volume.c_str(), 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (vol == INVALID_HANDLE_VALUE) return cached;
    STORAGE_DEVICE_NUMBER number{};
    DWORD bytes = 0;
    const bool gotNumber = DeviceIoControl(vol, IOCTL_STORAGE_GET_DEVICE_NUMBER, nullptr, 0, &number, sizeof(number), &bytes, nullptr);
    CloseHandle(vol);
    if (!gotNumber) return cached;
    const std::wstring drive = L"\\\\.\\PhysicalDrive" + std::to_wstring(number.DeviceNumber);
    HANDLE disk = CreateFileW(drive.c_str(), 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (disk == INVALID_HANDLE_VALUE) return cached;
    STORAGE_PROPERTY_QUERY query{};
    query.PropertyId = StorageDeviceTemperatureProperty;
    query.QueryType = PropertyStandardQuery;
    alignas(8) char out[512] = {};
    if (DeviceIoControl(disk, IOCTL_STORAGE_QUERY_PROPERTY, &query, sizeof(query), out, sizeof(out), &bytes, nullptr)) {
        const auto *data = reinterpret_cast<const STORAGE_TEMPERATURE_DATA_DESCRIPTOR *>(out);
        if (data->InfoCount > 0 && bytes >= sizeof(STORAGE_TEMPERATURE_DATA_DESCRIPTOR)) {
            const SHORT celsius = data->TemperatureInfo[0].Temperature;
            if (celsius > 0 && celsius < 150) cached = celsius;
        }
    }
    CloseHandle(disk);
    return cached;
}

Power power() {
    Power p;
    SYSTEM_POWER_STATUS s{};
    if (!GetSystemPowerStatus(&s)) return p;
    p.valid = true;
    p.onAc = s.ACLineStatus == 1;
    // BatteryFlag: 128 = sem bateria do sistema; 255 = estado desconhecido.
    p.hasBattery = s.BatteryFlag != 128 && s.BatteryFlag != 255;
    if (!p.hasBattery) return p;
    p.charging = (s.BatteryFlag & 8) != 0;
    if (s.BatteryLifePercent <= 100) p.percent = s.BatteryLifePercent;
    if (!p.onAc && s.BatteryLifeTime != DWORD(-1)) p.secondsLeft = qint64(s.BatteryLifeTime);
    return p;
}

}
