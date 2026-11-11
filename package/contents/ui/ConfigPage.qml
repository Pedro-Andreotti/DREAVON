import QtQuick
import QtQuick.Controls as QQC2

// Página rolável das configurações (substitui o KCM.SimpleKCM do Plasma).
// As propriedades cfg_<chave> de cada página são lidas e gravadas pela SettingsWindow.
QQC2.ScrollView {
    id: page
    padding: 18
    contentWidth: availableWidth
    clip: true
}
