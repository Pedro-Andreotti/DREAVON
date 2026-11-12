#include "systeminfo_win.h"

#include <QSettings>
#include <qt_windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <psapi.h>
#include <winioctl.h>
#include <initguid.h>   // antes do devpkey.h: define as chaves DEVPKEY_* neste arquivo
#include <cfgmgr32.h>
#include <devpkey.h>
#include <devquery.h>
#include <setupapi.h>
#include <hidsdi.h>
#include <hidpi.h>
#include <cstring>
#include <QHash>
#include <QSet>
#include <string>
#include <vector>

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

// Nível de bateria que o Windows guarda para aparelhos Bluetooth (o mesmo de Configurações).
// Chave NÃO documentada pela Microsoft (não está no devpkey.h); usada por várias ferramentas.
// Fica no nó "Hands-Free" dos fones clássicos. Só leitura: se não existir, a bateria fica -1.
DEFINE_DEVPROPKEY(DREAVON_DEVPKEY_BluetoothBattery, 0x104EA319, 0x6EE2, 0x4701, 0xBD, 0x47, 0x8D, 0xDB, 0xF4, 0x25, 0xBB, 0xE5, 2);

QList<Peripheral> peripherals() {
    using GetProps = HRESULT (WINAPI *)(DEV_OBJECT_TYPE, PCWSTR, ULONG, ULONG, const DEVPROPCOMPKEY *, PULONG, const DEVPROPERTY **);
    using FreeProps = void (WINAPI *)(ULONG, const DEVPROPERTY *);
    // DevGetObjectProperties está no cfgmgr32.dll, mas não no cfgmgr32.lib (só no onecore.lib).
    static const HMODULE cfgmgr = LoadLibraryW(L"cfgmgr32.dll");
    static const auto getProps = cfgmgr ? reinterpret_cast<GetProps>(GetProcAddress(cfgmgr, "DevGetObjectProperties")) : nullptr;
    static const auto freeProps = cfgmgr ? reinterpret_cast<FreeProps>(GetProcAddress(cfgmgr, "DevFreeObjectProperties")) : nullptr;
    if (!getProps || !freeProps) return {};

    // 1. Nós presentes, agrupados por contêiner (um contêiner = um aparelho).
    ULONG length = 0;
    if (CM_Get_Device_ID_List_SizeW(&length, nullptr, CM_GETIDLIST_FILTER_PRESENT) != CR_SUCCESS || length == 0) return {};
    std::vector<wchar_t> ids(length);
    if (CM_Get_Device_ID_ListW(nullptr, ids.data(), length, CM_GETIDLIST_FILTER_PRESENT) != CR_SUCCESS) return {};
    // Contêiner do próprio computador: seus componentes internos não são "dispositivos".
    static const GUID computer = {0x00000000, 0x0000, 0x0000, {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff}};
    // Barramentos de hardware externo; contêineres só com nós de software (SWD, ROOT…) ficam de fora.
    static const QSet<QString> physicalBuses = {"USB", "USBSTOR", "BTHENUM", "BTHLE", "BTHLEDEVICE", "BTHHFENUM"};
    struct Info { int battery = -1; bool physical = false; bool bluetooth = false; };
    QHash<QString, Info> containers;
    for (const wchar_t *id = ids.data(); *id; id += wcslen(id) + 1) {
        DEVINST node = 0;
        if (CM_Locate_DevNodeW(&node, const_cast<DEVINSTID_W>(id), CM_LOCATE_DEVNODE_NORMAL) != CR_SUCCESS) continue;
        GUID container; DEVPROPTYPE type = 0; ULONG size = sizeof(container);
        if (CM_Get_DevNode_PropertyW(node, &DEVPKEY_Device_ContainerId, &type, reinterpret_cast<PBYTE>(&container), &size, 0) != CR_SUCCESS
            || type != DEVPROP_TYPE_GUID || IsEqualGUID(container, computer)) continue;
        wchar_t key[40];
        StringFromGUID2(container, key, 40);
        Info &info = containers[QString::fromWCharArray(key)];
        const QString bus = QString::fromWCharArray(id).section('\\', 0, 0).toUpper();
        if (physicalBuses.contains(bus)) info.physical = true;
        if (bus.startsWith("BTH")) info.bluetooth = true;
        BYTE level = 0; size = sizeof(level);
        if (CM_Get_DevNode_PropertyW(node, &DREAVON_DEVPKEY_BluetoothBattery, &type, &level, &size, 0) == CR_SUCCESS
            && type == DEVPROP_TYPE_BYTE && level <= 100) info.battery = level;
    }

    // 2. Propriedades de cada contêiner: nome, categorias, conectado, se é de rede e a bateria
    //    documentada (System.Devices.BatteryLife / BatteryPlusCharging, do propkey.h).
    static const DEVPROPKEY batteryLife = {{0x49CD1F76, 0x5626, 0x4B17, {0xA4, 0xE8, 0x18, 0xB4, 0xAA, 0x1A, 0x22, 0x13}}, 10};
    static const DEVPROPKEY batteryPlusCharging = {{0x49CD1F76, 0x5626, 0x4B17, {0xA4, 0xE8, 0x18, 0xB4, 0xAA, 0x1A, 0x22, 0x13}}, 22};
    const DEVPROPCOMPKEY keys[] = {
        {DEVPKEY_NAME, DEVPROP_STORE_SYSTEM, nullptr},
        {DEVPKEY_DeviceContainer_Category, DEVPROP_STORE_SYSTEM, nullptr},
        {DEVPKEY_DeviceContainer_IsConnected, DEVPROP_STORE_SYSTEM, nullptr},
        {DEVPKEY_DeviceContainer_IsNetworkDevice, DEVPROP_STORE_SYSTEM, nullptr},
        {batteryLife, DEVPROP_STORE_SYSTEM, nullptr},
        {batteryPlusCharging, DEVPROP_STORE_SYSTEM, nullptr},
    };
    QList<Peripheral> result;
    for (auto it = containers.cbegin(); it != containers.cend(); ++it) {
        if (!it->physical) continue;
        ULONG count = 0; const DEVPROPERTY *props = nullptr;
        const std::wstring object = it.key().toStdWString();
        if (FAILED(getProps(DevObjectTypeDeviceContainer, object.c_str(), DevQueryFlagNone, ULONG(std::size(keys)), keys, &count, &props))) continue;
        QString name; QStringList categories; bool connected = true, network = false;
        int containerBattery = -1;
        for (ULONG i = 0; i < count; ++i) {
            const DEVPROPERTY &p = props[i];
            if (p.Type == DEVPROP_TYPE_EMPTY || !p.Buffer) continue;
            if (IsEqualDevPropKey(p.CompKey.Key, DEVPKEY_NAME) && p.Type == DEVPROP_TYPE_STRING)
                name = QString::fromWCharArray(static_cast<const wchar_t *>(p.Buffer));
            else if (IsEqualDevPropKey(p.CompKey.Key, DEVPKEY_DeviceContainer_Category) && p.Type == DEVPROP_TYPE_STRING_LIST)
                for (auto *c = static_cast<const wchar_t *>(p.Buffer); *c; c += wcslen(c) + 1) categories << QString::fromWCharArray(c);
            else if (IsEqualDevPropKey(p.CompKey.Key, DEVPKEY_DeviceContainer_IsConnected) && p.Type == DEVPROP_TYPE_BOOLEAN)
                connected = *static_cast<const DEVPROP_BOOLEAN *>(p.Buffer) != DEVPROP_FALSE;
            else if (IsEqualDevPropKey(p.CompKey.Key, DEVPKEY_DeviceContainer_IsNetworkDevice) && p.Type == DEVPROP_TYPE_BOOLEAN)
                network = *static_cast<const DEVPROP_BOOLEAN *>(p.Buffer) != DEVPROP_FALSE;
            else if (IsEqualDevPropKey(p.CompKey.Key, batteryLife) || IsEqualDevPropKey(p.CompKey.Key, batteryPlusCharging)) {
                int value = -1;
                if (p.Type == DEVPROP_TYPE_BYTE) value = *static_cast<const BYTE *>(p.Buffer);
                else if (p.Type == DEVPROP_TYPE_UINT32) value = int(*static_cast<const ULONG *>(p.Buffer));
                if (IsEqualDevPropKey(p.CompKey.Key, batteryLife) && value >= 0 && value <= 100) containerBattery = value;
            }
        }
        freeProps(count, props);
        if (!connected || network || name.isEmpty()) continue;
        // Nome como referência a recurso ("@arquivo.inf,%chave%;Texto"): usa o texto depois do ";".
        if (name.startsWith('@')) name = name.contains(';') ? name.section(';', -1) : QString();
        if (name.trimmed().isEmpty()) continue;
        auto has = [&categories](const char *prefix) {
            for (const QString &c : categories) if (c.startsWith(QLatin1String(prefix), Qt::CaseInsensitive)) return true;
            return false;
        };
        Peripheral device;
        device.container = it.key();
        device.name = name.trimmed();
        device.category = categories.join(',');
        device.percent = it->battery >= 0 ? it->battery : containerBattery;
        device.bluetooth = it->bluetooth;
        if (has("Audio")) device.kind = QStringLiteral("Fone");
        else if (has("Communication.Phone") || has("Phone")) device.kind = QStringLiteral("Celular");
        else if (has("Input.Mouse") && !has("Input.Keyboard")) device.kind = QStringLiteral("Mouse");
        else if (has("Input.Keyboard") && !has("Input.Mouse")) device.kind = QStringLiteral("Teclado");
        result.append(device);
    }
    return result;
}

namespace {
// Canal HID com tempo limite (E/S sobreposta): relatórios de 20 bytes do HID++ "longo".
// O receptor aceita vários leitores ao mesmo tempo (o G HUB continua funcionando).
class HidLink {
public:
    explicit HidLink(const std::wstring &path)
        : m_handle(CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                               OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr)),
          m_event(CreateEventW(nullptr, TRUE, FALSE, nullptr)) {}
    ~HidLink() {
        if (m_handle != INVALID_HANDLE_VALUE) { CancelIo(m_handle); CloseHandle(m_handle); }
        if (m_event) CloseHandle(m_event);
    }
    HidLink(const HidLink &) = delete;
    HidLink &operator=(const HidLink &) = delete;
    bool ok() const { return m_handle != INVALID_HANDLE_VALUE && m_event; }
    bool write(BYTE *data, DWORD size) { return io(true, data, size, 500) == size; }
    DWORD read(BYTE *data, DWORD size, DWORD timeoutMs) { return io(false, data, size, timeoutMs); }
private:
    DWORD io(bool writing, BYTE *data, DWORD size, DWORD timeoutMs) {
        OVERLAPPED ov{};
        ov.hEvent = m_event;
        ResetEvent(m_event);
        const BOOL started = writing ? WriteFile(m_handle, data, size, nullptr, &ov) : ReadFile(m_handle, data, size, nullptr, &ov);
        if (!started && GetLastError() != ERROR_IO_PENDING) return 0;
        DWORD done = 0;
        if (WaitForSingleObject(m_event, timeoutMs) != WAIT_OBJECT_0) {
            CancelIoEx(m_handle, &ov);
            GetOverlappedResult(m_handle, &ov, &done, TRUE);   // espera o cancelamento antes de sair (ov e data são locais)
            return 0;
        }
        return GetOverlappedResult(m_handle, &ov, &done, FALSE) ? done : 0;
    }
    HANDLE m_handle;
    HANDLE m_event;
};

// Uma consulta HID++ 2.0 (relatório longo 0x11): [0x11, aparelho, índice do recurso, (função << 4) | software, args...].
// Espera a resposta do mesmo aparelho/índice/função; ignora o tráfego de outros programas (ex.: G HUB).
// Devolve 1 com resposta, 0 com erro HID++ (recurso/aparelho não atende) e -1 sem resposta.
int hidppQueryOnce(HidLink &link, BYTE device, BYTE index, BYTE function, const BYTE *args, int argCount, BYTE *reply,
                   DWORD timeoutMs = 1000) {
    constexpr BYTE softwareId = 0x0A;
    BYTE request[20] = {0x11, device, index, BYTE((function << 4) | softwareId)};
    for (int i = 0; i < argCount && i < 16; ++i) request[4 + i] = args[i];
    if (!link.write(request, sizeof(request))) return -1;
    const ULONGLONG deadline = GetTickCount64() + timeoutMs;
    for (ULONGLONG now = GetTickCount64(); now < deadline; now = GetTickCount64()) {
        BYTE in[20] = {};
        if (link.read(in, sizeof(in), DWORD(deadline - now)) < 5) return -1;
        if (in[0] != 0x11 || in[1] != device) continue;
        if (in[2] == 0xFF && in[3] == index && in[4] == request[3]) return 0;   // erro HID++ 2.0
        if (in[2] == index && in[3] == request[3]) { std::memcpy(reply, in, sizeof(in)); return 1; }
    }
    return -1;
}

// Com uma nova tentativa: o receptor pode responder "ocupado" se o G HUB consultar ao mesmo tempo.
int hidppQuery(HidLink &link, BYTE device, BYTE index, BYTE function, const BYTE *args, int argCount, BYTE *reply) {
    const int first = hidppQueryOnce(link, device, index, function, args, argCount, reply);
    if (first == 1) return 1;
    Sleep(150);
    const int second = hidppQueryOnce(link, device, index, function, args, argCount, reply);
    return second == 1 ? 1 : qMax(first, second);
}

// Índice do recurso no aparelho (Root.GetFeature): >0 se suporta, 0 se não, -1 sem resposta.
int featureIndex(HidLink &link, BYTE device, quint16 feature) {
    const BYTE args[2] = {BYTE(feature >> 8), BYTE(feature & 0xFF)};
    BYTE reply[20];
    const int r = hidppQuery(link, device, 0x00, 0, args, 2, reply);
    return r == 1 ? reply[4] : r;
}

// Interface "longa" do HID++ de um receptor Logitech: fabricante 0x046D, página 0xFF00, uso 0x0002.
bool isLogitechLongInterface(const std::wstring &path) {
    HANDLE h = CreateFileW(path.c_str(), 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (h == INVALID_HANDLE_VALUE) return false;
    bool match = false;
    HIDD_ATTRIBUTES attributes{};
    attributes.Size = sizeof(attributes);
    PHIDP_PREPARSED_DATA preparsed = nullptr;
    if (HidD_GetAttributes(h, &attributes) && attributes.VendorID == 0x046D && HidD_GetPreparsedData(h, &preparsed)) {
        HIDP_CAPS caps{};
        match = HidP_GetCaps(preparsed, &caps) == HIDP_STATUS_SUCCESS && caps.UsagePage == 0xFF00 && caps.Usage == 0x0002;
        HidD_FreePreparsedData(preparsed);
    }
    CloseHandle(h);
    return match;
}

// Tipo informado pelo recurso DeviceNameType (0x0005), na numeração do HID++ 2.0.
QString kindForHidppType(BYTE type) {
    switch (type) {
    case 0: case 2: return QStringLiteral("Teclado");          // teclado, teclado numérico
    case 3: case 4: case 5: return QStringLiteral("Mouse");    // mouse, trackpad, trackball
    case 8: return QStringLiteral("Fone");                     // headset
    default: return {};
    }
}
}

QList<LogitechBattery> logitechBatteries() {
    QList<LogitechBattery> result;
    GUID hidGuid;
    HidD_GetHidGuid(&hidGuid);
    HDEVINFO set = SetupDiGetClassDevsW(&hidGuid, nullptr, nullptr, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (set == INVALID_HANDLE_VALUE) return result;
    SP_DEVICE_INTERFACE_DATA data{};
    data.cbSize = sizeof(data);
    for (DWORD i = 0; SetupDiEnumDeviceInterfaces(set, nullptr, &hidGuid, i, &data); ++i) {
        DWORD required = 0;
        SetupDiGetDeviceInterfaceDetailW(set, &data, nullptr, 0, &required, nullptr);
        if (required < sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W)) continue;
        std::vector<BYTE> buffer(required);
        auto *detail = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W *>(buffer.data());
        detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
        SP_DEVINFO_DATA devInfo{};
        devInfo.cbSize = sizeof(devInfo);
        if (!SetupDiGetDeviceInterfaceDetailW(set, &data, detail, required, nullptr, &devInfo)) continue;
        const std::wstring path = detail->DevicePath;
        if (!isLogitechLongInterface(path)) continue;
        // Contêiner do receptor: o mesmo aparelho que peripherals() já lista.
        GUID container;
        DEVPROPTYPE type = 0;
        if (!SetupDiGetDevicePropertyW(set, &devInfo, &DEVPKEY_Device_ContainerId, &type, reinterpret_cast<PBYTE>(&container),
                                       sizeof(container), nullptr, 0) || type != DEVPROP_TYPE_GUID) continue;
        wchar_t key[40];
        StringFromGUID2(container, key, 40);

        HidLink link(path);
        if (!link.ok()) continue;
        for (BYTE device = 1; device <= 6; ++device) {   // índices de aparelho num receptor
            BYTE reply[20];
            LogitechBattery battery;
            battery.container = QString::fromWCharArray(key);
            // Sonda rápida do índice (500 ms, sem nova tentativa): índice vazio não responde.
            const BYTE probeArgs[2] = {0x10, 0x04};
            const int probe = hidppQueryOnce(link, device, 0x00, 0, probeArgs, 2, reply, 500);
            if (probe < 0) continue;
            const int unified = probe == 1 ? reply[4] : 0;   // índice do 0x1004 (0 = não suporta ou erro HID++)
            if (unified > 0 && hidppQuery(link, device, BYTE(unified), 1, nullptr, 0, reply) == 1) {
                battery.percent = reply[4];                         // UnifiedBattery.GetStatus: carga em %
                battery.charging = reply[6] == 1 || reply[6] == 2;  // 1 carregando, 2 carregando devagar
            } else {
                const int status = featureIndex(link, device, 0x1000);
                if (status <= 0 || hidppQuery(link, device, BYTE(status), 0, nullptr, 0, reply) != 1) continue;
                battery.percent = reply[4];                         // BatteryStatus.GetBatteryLevelStatus
                battery.charging = reply[6] >= 1 && reply[6] <= 2;
            }
            if (battery.percent < 0 || battery.percent > 100) continue;
            const int nameType = featureIndex(link, device, 0x0005);
            if (nameType > 0 && hidppQuery(link, device, BYTE(nameType), 2, nullptr, 0, reply) == 1)
                battery.kind = kindForHidppType(reply[4]);          // DeviceNameType.GetDeviceType
            result.append(battery);
        }
    }
    SetupDiDestroyDeviceInfoList(set);
    return result;
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
