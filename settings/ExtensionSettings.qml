import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var dock
  spacing: Style.spacing.sm

  Repeater {
    model: page.dock.extensions.builtIns

    Toggle {
      id: extensionToggle

      required property var modelData

      Layout.fillWidth: true
      label: modelData.label
      foreground: Commons.Color.popups.text
      enabled: !page.dock.savingExtension
      checked: page.dock.extensions.enabledReferences.indexOf(modelData.id) >= 0
      Accessible.role: Accessible.CheckBox
      Accessible.name: label
      Accessible.checked: checked
      Accessible.onPressAction: if (enabled) clicked()
      onClicked: page.dock.setExtensionEnabled(modelData.id, !checked)
    }
  }

  Text {
    Layout.fillWidth: true
    visible: text.length > 0
    text: page.dock.extensionSaveError
    textFormat: Text.PlainText
    color: Commons.Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }
}
