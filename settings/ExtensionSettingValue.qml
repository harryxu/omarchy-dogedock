pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Loader {
  id: editor

  required property var field
  required property string label
  property var value
  property bool adding: false
  signal committed(var value)

  sourceComponent: {
    if (field.type === "directory") return directoryEditor
    if (field.type === "boolean" && !adding) return booleanEditor
    if (field.type === "choice" || field.type === "boolean") return choiceEditor
    return textEditor
  }

  Component {
    id: textEditor

    ColumnLayout {
      id: input

      readonly property bool numeric: editor.field.type === "number"
      readonly property var parsedValue: numeric ? Number(textField.text) : textField.text
      readonly property bool valid: !numeric || (/^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(textField.text.trim())
        && Number.isFinite(parsedValue))

      spacing: Style.spacing.xs

      function reset() {
        textField.clear()
      }

      function commit() {
        if (!editor.enabled || !valid || (!editor.adding && editor.value === parsedValue)) return
        editor.committed(parsedValue)
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xs

        TextField {
          id: textField

          Layout.fillWidth: true
          Layout.minimumWidth: 0
          text: editor.adding || editor.value === undefined ? "" : String(editor.value)
          placeholderText: editor.adding ? qsTr("New value") : ""
          foreground: Commons.Color.popups.text
          Accessible.name: editor.label
          onAccepted: input.commit()
        }

        Button {
          text: editor.adding ? qsTr("Add") : qsTr("Save")
          Accessible.name: editor.adding ? qsTr("Add to %1").arg(editor.label) : qsTr("Save %1").arg(editor.label)
          foreground: Commons.Color.popups.text
          focusable: true
          enabled: input.valid && (editor.adding || input.parsedValue !== editor.value)
          onClicked: input.commit()
        }
      }

      Text {
        Layout.fillWidth: true
        visible: !input.valid && textField.text.length > 0
        text: qsTr("Enter a valid number.")
        textFormat: Text.PlainText
        color: Commons.Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }
    }
  }

  Component {
    id: booleanEditor

    Toggle {
      label: editor.label
      checked: editor.value === true
      foreground: Commons.Color.popups.text
      Accessible.role: Accessible.CheckBox
      Accessible.name: label
      Accessible.checked: checked
      Accessible.onPressAction: if (enabled) clicked()
      onClicked: if (enabled) editor.committed(!checked)
    }
  }

  Component {
    id: choiceEditor

    Dropdown {
      id: choices

      readonly property bool booleanOptions: editor.field.type === "boolean"
      readonly property string confirmedValue: editor.adding ? qsTr("Add a value…") : String(editor.value || "")

      label: editor.label
      showLabel: false
      Accessible.name: editor.adding ? qsTr("Add to %1").arg(editor.label) : editor.label
      options: booleanOptions ? [{ value: "true", label: qsTr("On") }, { value: "false", label: qsTr("Off") }]
        : editor.field.options || []
      value: confirmedValue
      onChanged: function(selection) {
        // Dropdown sets its value before emitting changed. The saved value owns the display.
        choices.value = Qt.binding(function() { return choices.confirmedValue })
        var value = booleanOptions ? selection === "true" : selection
        if (enabled && (editor.adding || value !== editor.value)) editor.committed(value)
      }
    }
  }

  Component {
    id: directoryEditor

    RowLayout {
      spacing: Style.spacing.xs

      Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: !editor.adding && !!editor.value
        text: editor.value || ""
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideMiddle
      }

      Button {
        text: editor.adding ? qsTr("Add directory…") : qsTr("Choose directory…")
        Accessible.name: text
        focusable: true
        bordered: true
        foreground: Commons.Color.popups.text
        onClicked: if (enabled) picker.open()

        FolderDialog {
          id: picker

          objectName: "extensionDirectoryPicker"
          title: editor.label
          onAccepted: {
            var uri = String(selectedFolder)
            if (editor.enabled && uri.startsWith("file:///")) {
              try {
                editor.committed(decodeURIComponent(uri.slice("file://".length)))
              } catch (error) {
                console.warn("DogeDock: could not read the selected directory", error)
              }
            }
          }
        }
      }

      Button {
        visible: !editor.adding && !!editor.value
        text: qsTr("Clear")
        Accessible.name: qsTr("Clear %1").arg(editor.label)
        focusable: true
        foreground: Commons.Color.popups.text
        onClicked: if (enabled) editor.committed("")
      }
    }
  }
}
