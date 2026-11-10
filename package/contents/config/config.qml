import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory { name: "Geral"; icon: "preferences-system"; source: "ConfigGeneral.qml" }
    ConfigCategory { name: "Cartões"; icon: "view-grid-symbolic"; source: "ConfigCards.qml" }
    ConfigCategory { name: "Aparência"; icon: "preferences-desktop-color"; source: "ConfigAppearance.qml" }
}
