#include "networkinfo_win.h"

#include <QHostAddress>
#include <QVarLengthArray>

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <wlanapi.h>

namespace NetworkInfoWin {

namespace {

bool countedType(ULONG type) {
    return type == IF_TYPE_ETHERNET_CSMACD || type == IF_TYPE_IEEE80211
        || type == IF_TYPE_WWANPP || type == IF_TYPE_WWANPP2;
}

QString typeLabel(ULONG type, bool hardware) {
    if (type == IF_TYPE_TUNNEL || type == IF_TYPE_PPP) return QStringLiteral("VPN");
    if (!hardware) return QStringLiteral("Rede");   // adaptador virtual (VPN em modo Ethernet, Hyper-V...)
    if (type == IF_TYPE_IEEE80211) return QStringLiteral("Wi-Fi");
    if (type == IF_TYPE_ETHERNET_CSMACD) return QStringLiteral("Cabo");
    if (type == IF_TYPE_WWANPP || type == IF_TYPE_WWANPP2) return QStringLiteral("Móvel");
    return QStringLiteral("Rede");
}

// Índice da interface da melhor rota até um destino público. Nenhum pacote é enviado: o Windows
// só consulta a tabela de rotas. IPv4 primeiro (1.1.1.1); se não houver rota, IPv6 (2606:4700:4700::1111).
bool bestInterface(DWORD *index) {
    sockaddr_in v4 = {};
    v4.sin_family = AF_INET;
    v4.sin_addr.s_addr = htonl(0x01010101);
    if (GetBestInterfaceEx(reinterpret_cast<sockaddr *>(&v4), index) == NO_ERROR) return true;
    sockaddr_in6 v6 = {};
    v6.sin6_family = AF_INET6;
    const unsigned char addr[16] = {0x26, 0x06, 0x47, 0x00, 0x47, 0x00, 0, 0, 0, 0, 0, 0, 0, 0, 0x11, 0x11};
    memcpy(&v6.sin6_addr, addr, sizeof addr);
    return GetBestInterfaceEx(reinterpret_cast<sockaddr *>(&v6), index) == NO_ERROR;
}

// SSID e sinal da interface Wi-Fi (WLAN API). Nas versões recentes do Windows 11, um app da área de
// trabalho só recebe esses dados com a localização permitida; sem ela, WlanQueryInterface devolve
// ERROR_ACCESS_DENIED. O sinal vem na mesma resposta, então também fica indisponível.
void readWifi(const NET_LUID &luid, Connection *c) {
    GUID guid;
    if (ConvertInterfaceLuidToGuid(&luid, &guid) != NO_ERROR) return;
    DWORD version = 0;
    HANDLE client = nullptr;
    if (WlanOpenHandle(2, nullptr, &version, &client) != ERROR_SUCCESS) {
        c->hint = QStringLiteral("O serviço de Wi-Fi do Windows (WLAN AutoConfig) não respondeu.");
        return;
    }
    DWORD size = 0;
    WLAN_CONNECTION_ATTRIBUTES *attr = nullptr;
    const DWORD rc = WlanQueryInterface(client, &guid, wlan_intf_opcode_current_connection, nullptr,
                                        &size, reinterpret_cast<PVOID *>(&attr), nullptr);
    if (rc == ERROR_SUCCESS && attr) {
        if (attr->isState == wlan_interface_state_connected) {
            const DOT11_SSID &ssid = attr->wlanAssociationAttributes.dot11Ssid;
            const ULONG len = qMin<ULONG>(ssid.uSSIDLength, DOT11_SSID_MAX_LENGTH);
            c->name = QString::fromUtf8(reinterpret_cast<const char *>(ssid.ucSSID), int(len));
            c->strength = int(attr->wlanAssociationAttributes.wlanSignalQuality);
        }
        WlanFreeMemory(attr);
    } else if (rc == ERROR_ACCESS_DENIED) {
        c->hint = QStringLiteral("O Windows só informa o nome e o sinal do Wi-Fi a apps com acesso à localização. "
                                 "Para mostrar, ative em Configurações > Privacidade e segurança > Localização: "
                                 "\"Serviços de localização\" e \"Permitir que aplicativos da área de trabalho "
                                 "acessem sua localização\".");
    } else {
        c->hint = QStringLiteral("O Windows não informou o nome e o sinal do Wi-Fi.");
    }
    WlanCloseHandle(client, nullptr);
    if (c->name.isEmpty()) c->name = QStringLiteral("Nome da rede indisponível");
}

}

bool counters(QList<Counter> *out, int *skipped) {
    out->clear();
    if (skipped) *skipped = 0;
    MIB_IF_TABLE2 *table = nullptr;
    if (GetIfTable2(&table) != NO_ERROR || !table) return false;
    for (ULONG i = 0; i < table->NumEntries; ++i) {
        const MIB_IF_ROW2 &row = table->Table[i];
        const bool counted = row.InterfaceAndOperStatusFlags.HardwareInterface
            && !row.InterfaceAndOperStatusFlags.FilterInterface
            && row.OperStatus == IfOperStatusUp && countedType(row.Type);
        if (!counted) {
            if (skipped) ++*skipped;
            continue;
        }
        out->append({row.InterfaceLuid.Value, row.InOctets, row.OutOctets});
    }
    FreeMibTable(table);
    return true;
}

Connection primary() {
    Connection c;
    DWORD index = 0;
    if (!bestInterface(&index)) return c;   // sem rota: offline

    ULONG size = 16 * 1024;
    QVarLengthArray<char, 16 * 1024> buffer(size);
    const ULONG flags = GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER;
    ULONG rc = ERROR_BUFFER_OVERFLOW;
    for (int attempt = 0; attempt < 3 && rc == ERROR_BUFFER_OVERFLOW; ++attempt) {
        buffer.resize(size);
        rc = GetAdaptersAddresses(AF_UNSPEC, flags, nullptr,
                                  reinterpret_cast<IP_ADAPTER_ADDRESSES *>(buffer.data()), &size);
    }
    if (rc != NO_ERROR) return c;

    for (auto *a = reinterpret_cast<IP_ADAPTER_ADDRESSES *>(buffer.data()); a; a = a->Next) {
        if (a->IfIndex != index && a->Ipv6IfIndex != index) continue;
        if (a->OperStatus != IfOperStatusUp) return c;
        MIB_IF_ROW2 row = {};
        row.InterfaceLuid = a->Luid;
        const bool hardware = GetIfEntry2(&row) == NO_ERROR && row.InterfaceAndOperStatusFlags.HardwareInterface;
        c.valid = true;
        c.luid = a->Luid.Value;
        c.type = typeLabel(a->IfType, hardware);
        for (auto *u = a->FirstUnicastAddress; u; u = u->Next) {
            if (u->Address.lpSockaddr && u->Address.lpSockaddr->sa_family == AF_INET) {
                c.address = QHostAddress(u->Address.lpSockaddr).toString();
                break;
            }
        }
        if (a->IfType == IF_TYPE_IEEE80211) readWifi(a->Luid, &c);
        else c.name = QString::fromWCharArray(a->FriendlyName);
        return c;
    }
    return c;
}

}
