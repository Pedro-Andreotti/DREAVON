import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

// Kirigami.FormLayout simplificado: duas colunas (rótulo à direita, campo à esquerda).
// Lê o rótulo de Kirigami.FormData.label e transforma os itens com FormData.isSection em títulos.
// Os filhos precisam ser declarados diretamente dentro do FormLayout (como nas páginas de configuração).
Item {
    id: form
    default property alias content: holder.data
    property bool wideMode: true
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    Item { id: holder; visible: false }

    GridLayout {
        id: grid
        width: form.width
        columns: 2
        columnSpacing: 12
        rowSpacing: 8
    }

    Component {
        id: sectionComponent
        ColumnLayout {
            property string text
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.topMargin: 14
            spacing: 4
            QQC2.Label { text: parent.text; font.bold: true; font.pixelSize: 15; color: Theme.textColor }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.rgba(1, 1, 1, 0.12) }
        }
    }
    Component {
        id: labelComponent
        QQC2.Label {
            property Item buddy
            visible: buddy ? buddy.visible : true
            color: Theme.textColor
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        }
    }

    Component.onCompleted: {
        const items = []
        for (let i = 0; i < holder.children.length; ++i) items.push(holder.children[i])
        for (const child of items) {
            const data = FormLayoutHelper.formData(child)
            if (data && data.isSection) {
                // O próprio separador fica guardado; o título já desenha a linha.
                sectionComponent.createObject(grid, {text: data.label})
                continue
            }
            labelComponent.createObject(grid, {text: data ? data.label : "", buddy: child})
            child.parent = grid
        }
    }
}
