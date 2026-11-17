pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: editor

  required property var field
  required property var value
  property bool invalid: false
  property string editError: ""
  readonly property int itemCount: field.multiple ? value.length : 0
  signal edited(var value)

  spacing: Style.spacing.xs
  onValueChanged: editError = ""

  function editItem(index, value) {
    var items = editor.value.slice()
    if (field.type === "directory" && items.indexOf(value) >= 0) {
      if (items[index] !== value) editError = qsTr("That directory is already in the list.")
      return
    }
    if (index === items.length) items.push(value)
    else items[index] = value
    editor.edited(items)
  }

  function moveItem(index, to) {
    if (to < 0 || to >= itemCount) return
    var items = editor.value.slice()
    items.splice(to, 0, items.splice(index, 1)[0])
    editor.edited(items)
  }

  function removeItem(index) {
    var items = editor.value.slice()
    items.splice(index, 1)
    editor.edited(items)
  }

  Text {
    Layout.fillWidth: true
    visible: editor.field.multiple || editor.field.type !== "boolean"
    text: editor.field.label
    textFormat: Text.PlainText
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    wrapMode: Text.Wrap
  }

  ExtensionSettingValue {
    Layout.fillWidth: true
    active: !editor.field.multiple
    visible: active
    field: editor.field
    value: editor.field.multiple ? undefined : editor.value
    label: editor.field.label
    onCommitted: function(value) { editor.edited(value) }
  }

  Repeater {
    model: editor.itemCount

    GridLayout {
      id: entry

      required property int index
      readonly property string itemLabel: qsTr("%1, item %2").arg(editor.field.label).arg(index + 1)

      Layout.fillWidth: true
      Layout.minimumWidth: 0
      columns: width < Style.space(480) ? 1 : 2
      columnSpacing: Style.spacing.xs
      rowSpacing: Style.spacing.xs

      RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: Style.spacing.xs

        Text {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          visible: editor.field.type === "directory"
          text: visible ? editor.value[entry.index] || "" : ""
          textFormat: Text.PlainText
          elide: Text.ElideMiddle
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        ExtensionSettingValue {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          active: editor.field.type !== "directory"
          visible: active
          field: editor.field
          value: editor.value[entry.index]
          label: entry.itemLabel
          onCommitted: function(value) { editor.editItem(entry.index, value) }
        }
      }

      RowLayout {
        spacing: Style.spacing.xs

        Button {
          text: qsTr("Up")
          Accessible.name: qsTr("Move %1 up").arg(entry.itemLabel)
          foreground: Commons.Color.popups.text
          focusable: true
          enabled: entry.index > 0
          onClicked: if (enabled) editor.moveItem(entry.index, entry.index - 1)
        }

        Button {
          text: qsTr("Down")
          Accessible.name: qsTr("Move %1 down").arg(entry.itemLabel)
          foreground: Commons.Color.popups.text
          focusable: true
          enabled: entry.index + 1 < editor.itemCount
          onClicked: if (enabled) editor.moveItem(entry.index, entry.index + 1)
        }

        Button {
          text: qsTr("Remove")
          Accessible.name: qsTr("Remove %1").arg(entry.itemLabel)
          foreground: Commons.Color.popups.text
          focusable: true
          onClicked: if (enabled) editor.removeItem(entry.index)
        }
      }
    }
  }

  ExtensionSettingValue {
    id: addValue

    Layout.fillWidth: true
    active: editor.field.multiple
    visible: active
    field: editor.field
    label: editor.field.label
    adding: true
    onCommitted: function(value) { editor.editItem(editor.itemCount, value) }

    Connections {
      target: editor
      function onItemCountChanged() {
        if (addValue.item && typeof addValue.item.reset === "function") addValue.item.reset()
      }
    }
  }

  Text {
    Layout.fillWidth: true
    visible: text.length > 0
    text: editor.editError || (editor.invalid ? qsTr("Some saved values are invalid. Edit this setting to correct them.") : "")
    textFormat: Text.PlainText
    color: Commons.Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
  }
}
