import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var dock
  spacing: Style.spacing.md

  Repeater {
    model: page.dock.extensions.settingsSources

    ColumnLayout {
      id: extension

      required property var modelData

      Layout.fillWidth: true
      spacing: Style.spacing.sm

      Toggle {
        Layout.fillWidth: true
        label: extension.modelData.label
        foreground: Commons.Color.popups.text
        enabled: !page.dock.savingExtension
        checked: extension.modelData.configuredEnabled
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checked: checked
        Accessible.onPressAction: if (enabled) clicked()
        onClicked: if (enabled) page.dock.setExtensionEnabled(extension.modelData.reference, !checked)
      }

      Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: extension.modelData.error
        textFormat: Text.PlainText
        color: Commons.Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
      }

      Repeater {
        model: extension.modelData.configuredEnabled && !extension.modelData.error ? extension.modelData.fields : []

        ExtensionSettingField {
          required property var modelData

          Layout.fillWidth: true
          Layout.leftMargin: Style.spacing.md
          Layout.rightMargin: Style.spacing.sm
          enabled: !page.dock.savingExtension
          field: modelData
          value: extension.modelData.resolved.values[field.key]
          invalid: extension.modelData.resolved.invalid[field.key] === true
          onEdited: function(value) {
            // QML signals can deliver JS arrays as QVariantList sequences.
            page.dock.setExtensionSetting(extension.modelData.reference, field.key, field.multiple ? Array.from(value) : value)
          }
        }
      }
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
