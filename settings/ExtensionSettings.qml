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

    BorderSurface {
      id: extension

      required property var modelData
      readonly property var fields: modelData.configuredEnabled && !modelData.error ? modelData.fields : []
      readonly property bool hasDetails: fields.length > 0 || modelData.error.length > 0

      Layout.fillWidth: true
      implicitWidth: group.implicitWidth + contentLeftInset + contentRightInset
      implicitHeight: group.implicitHeight + contentTopInset + contentBottomInset
      color: "transparent"
      radius: Style.cornerRadius
      borderSpec: Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      ColumnLayout {
        id: group

        anchors.fill: parent
        anchors.leftMargin: extension.contentLeftInset
        anchors.rightMargin: extension.contentRightInset
        anchors.topMargin: extension.contentTopInset
        anchors.bottomMargin: extension.contentBottomInset
        spacing: 0

        Toggle {
          Layout.fillWidth: true
          label: extension.modelData.label
          foreground: Commons.Color.popups.text
          borderSpec: activeFocus ? Border.controlSpec("focus", foreground, accent) : Border.none()
          enabled: !page.dock.savingExtension
          checked: extension.modelData.configuredEnabled
          Accessible.role: Accessible.CheckBox
          Accessible.name: label
          Accessible.checked: checked
          Accessible.onPressAction: if (enabled) clicked()
          onClicked: if (enabled) page.dock.setExtensionEnabled(extension.modelData.reference, !checked)
        }

        Rectangle {
          visible: extension.hasDetails
          Layout.fillWidth: true
          implicitHeight: Style.spacing.hairline
          color: Util.alpha(Commons.Color.popups.text, 0.2)
        }

        ColumnLayout {
          visible: extension.hasDetails
          Layout.fillWidth: true
          Layout.leftMargin: Style.spacing.rowPaddingX
          Layout.rightMargin: Style.spacing.rowPaddingX
          Layout.topMargin: Style.spacing.sm
          Layout.bottomMargin: Style.spacing.sm
          spacing: Style.spacing.md

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
            model: extension.fields

            ExtensionSettingField {
              required property var modelData

              Layout.fillWidth: true
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
