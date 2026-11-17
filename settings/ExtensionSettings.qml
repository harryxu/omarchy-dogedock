import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var dock
  spacing: Style.spacing.md

  Button {
    text: qsTr("Add external extension…")
    foreground: Commons.Color.popups.text
    bordered: true
    focusable: true
    enabled: !page.dock.savingExtension
    Accessible.name: text
    onClicked: if (enabled) picker.open()

    FolderDialog {
      id: picker

      objectName: "externalExtensionPicker"
      title: qsTr("Choose an extension directory")
      onAccepted: {
        var uri = String(selectedFolder)
        if (uri.startsWith("file:///")) {
          try {
            page.dock.addExternalExtension(decodeURIComponent(uri.slice("file://".length)))
          } catch (error) {
            console.warn("DogeDock: could not read the selected extension directory", error)
          }
        }
      }
    }
  }

  Text {
    Layout.fillWidth: true
    text: qsTr("Choose a directory containing manifest.json. Only add extensions you trust; they run with your user permissions.")
    textFormat: Text.PlainText
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
  }

  Repeater {
    model: page.dock.extensions.settingsSources

    BorderSurface {
      id: extension

      required property var modelData
      readonly property var fields: modelData.configuredEnabled && !modelData.error ? modelData.fields : []
      readonly property bool hasDetails: fields.length > 0 || modelData.error.length > 0

      Layout.fillWidth: true
      Layout.minimumWidth: 0
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

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs

          Toggle {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
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

          Button {
            visible: extension.modelData.external
            text: qsTr("Remove")
            Accessible.name: qsTr("Remove %1").arg(extension.modelData.label)
            foreground: Commons.Color.popups.text
            focusable: true
            enabled: !page.dock.savingExtension
            onClicked: if (enabled) page.dock.removeExternalExtension(extension.modelData.reference)
          }
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
          Layout.minimumWidth: 0
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
              Layout.minimumWidth: 0
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
