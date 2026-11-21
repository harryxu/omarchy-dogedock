import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var dock
  signal openSettingsPanel(string reference)
  spacing: Style.spacing.md

  RowLayout {
    Layout.fillWidth: true
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
      id: guideLink

      Layout.fillWidth: true
      Layout.minimumWidth: 0
      horizontalAlignment: Text.AlignRight
      text: qsTr("Write your own extension")
      textFormat: Text.PlainText
      color: Commons.Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.underline: true
      font.bold: activeFocus
      wrapMode: Text.Wrap
      activeFocusOnTab: true
      Accessible.role: Accessible.Link
      Accessible.name: text
      Accessible.onPressAction: openGuide()
      Keys.onReturnPressed: openGuide()
      Keys.onEnterPressed: openGuide()

      function openGuide() {
        Qt.openUrlExternally("https://github.com/harryxu/omarchy-dogedock/blob/master/docs/extension-development.md")
      }

      HoverHandler { cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: guideLink.openGuide() }
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
      readonly property var fields: !modelData.hasSettingsPanel && modelData.configuredEnabled && !modelData.error ? modelData.fields : []
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

        BorderSurface {
          id: toggleRow

          property string label: extension.modelData.label
          property bool checked: extension.modelData.configuredEnabled

          signal clicked()

          Layout.fillWidth: true
          Layout.minimumWidth: 0
          implicitHeight: Math.max(54, rowLayout.implicitHeight + contentTopInset + contentBottomInset)
          color: Style.controlFill(activeFocus, rowHover.hovered, Commons.Color.popups.text, Commons.Color.accent)
          borderSpec: activeFocus ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
          radius: Style.cornerRadius
          activeFocusOnTab: true
          enabled: !page.dock.savingExtension
          Accessible.role: Accessible.CheckBox
          Accessible.name: label
          Accessible.checked: checked
          Accessible.onPressAction: clicked()
          Keys.onReturnPressed: clicked()
          Keys.onEnterPressed: clicked()
          Keys.onSpacePressed: clicked()
          onClicked: if (enabled) page.dock.setExtensionEnabled(extension.modelData.reference, !checked)

          Behavior on color { ColorAnimation { duration: Style.duration(100) } }

          HoverHandler { id: rowHover }

          // The row owns the click, so the switch stays presentation only and
          // the action buttons keep their own hit areas above it.
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleRow.clicked()
          }

          RowLayout {
            id: rowLayout

            anchors.fill: parent
            anchors.leftMargin: toggleRow.contentLeftInset + Style.spacing.rowPaddingX
            anchors.rightMargin: toggleRow.contentRightInset + Style.spacing.rowPaddingX
            spacing: Style.spacing.controlGap

            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              Layout.alignment: Qt.AlignVCenter
              text: toggleRow.label
              textFormat: Text.PlainText
              color: Commons.Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
            }

            Row {
              Layout.alignment: Qt.AlignVCenter
              spacing: Style.spacing.xxs

              PanelActionButton {
                visible: extension.modelData.hasSettingsPanel
                enabled: !!extension.modelData.settingsPanel
                iconText: "󰒓"
                tooltipText: qsTr("Settings")
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Settings for %1").arg(extension.modelData.label)
                foreground: Commons.Color.popups.text
                fontFamily: Style.font.family
                focusable: true
                onClicked: if (enabled) page.openSettingsPanel(extension.modelData.reference)
              }

              PanelActionButton {
                visible: extension.modelData.external
                enabled: !page.dock.savingExtension
                iconText: "󰩹"
                tooltipText: qsTr("Remove")
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Remove %1").arg(extension.modelData.label)
                foreground: Commons.Color.popups.text
                hoverColor: Commons.Color.urgent
                fontFamily: Style.font.family
                focusable: true
                onClicked: if (enabled) page.dock.removeExternalExtension(extension.modelData.reference)
              }
            }

            ToggleSwitch {
              Layout.alignment: Qt.AlignVCenter
              checked: toggleRow.checked
              interactive: false
              foreground: Commons.Color.popups.text
            }
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
