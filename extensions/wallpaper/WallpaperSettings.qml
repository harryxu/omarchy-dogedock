pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var wallpaper
  readonly property bool directoryMode: mode === "directory"
  readonly property string selectedPath: directoryMode ? directory : image
  readonly property bool validInterval: /^\d+$/.test(minutesField.text) && minutesField.acceptableInput
  property string mode: "single"
  property string image: ""
  property string directory: ""

  spacing: Style.spacing.md

  function loadDraft() {
    var saved = wallpaper.config
    mode = saved.mode
    image = saved.image
    directory = saved.directory
    minutesField.text = String(saved.minutes)
  }

  function apply() {
    if (!applyButton.enabled) return
    wallpaper.save({
      mode: mode, image: image, directory: directory,
      minutes: validInterval ? Number(minutesField.text) : wallpaper.config.minutes
    })
  }

  function pathFromUrl(url) {
    try {
      var uri = String(url)
      if (uri.startsWith("file:///")) return wallpaper.localPath(decodeURIComponent(uri.slice("file://".length)))
    } catch (error) {}
    return ""
  }

  Component.onCompleted: loadDraft()
  Connections {
    target: page.wallpaper
    function onReadyChanged() { page.loadDraft() }
  }

  component Label: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    textFormat: Text.PlainText
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.Wrap
  }

  ButtonGroup {
    options: [
      { value: "single", label: qsTr("Single image") },
      { value: "directory", label: qsTr("Directory rotation") }
    ]
    value: page.mode
    foreground: Commons.Color.popups.text
    enabled: page.wallpaper.ready && !page.wallpaper.busy
    onChanged: function(selection) { page.mode = selection }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.sm

    Button {
      text: page.directoryMode ? qsTr("Choose directory…") : qsTr("Choose image…")
      foreground: Commons.Color.popups.text
      focusable: true
      enabled: page.wallpaper.ready && !page.wallpaper.busy
      onClicked: {
        if (page.directoryMode) directoryPicker.open()
        else imagePicker.open()
      }
    }

    Label {
      text: page.selectedPath
      wrapMode: Text.WrapAnywhere
    }
  }

  RowLayout {
    visible: page.directoryMode
    spacing: Style.spacing.sm

    Label { text: qsTr("Interval (minutes)") }

    TextField {
      id: minutesField

      Layout.preferredWidth: Style.space(72)
      enabled: page.wallpaper.ready && !page.wallpaper.busy
      foreground: Commons.Color.popups.text
      Accessible.name: qsTr("Interval (minutes)")
      validator: IntValidator { bottom: 1; top: 1440 }
      inputMethodHints: Qt.ImhDigitsOnly
      onAccepted: page.apply()
    }
  }

  Label {
    visible: page.directoryMode && !page.validInterval
    text: qsTr("Enter an interval from 1 to 1440 minutes.")
    color: Commons.Color.urgent
  }

  Button {
    id: applyButton

    text: qsTr("Apply")
    foreground: Commons.Color.popups.text
    bordered: true
    focusable: true
    enabled: page.wallpaper.ready && !page.wallpaper.busy && !!page.selectedPath
      && (!page.directoryMode || page.validInterval)
    onClicked: page.apply()
  }

  Label {
    visible: page.wallpaper.busy || text.length > 0
    text: page.wallpaper.busy ? qsTr("Applying wallpaper…") : page.wallpaper.error
    color: page.wallpaper.busy ? Commons.Color.popups.text : Commons.Color.urgent
  }

  FileDialog {
    id: imagePicker

    objectName: "wallpaperImagePicker"
    title: qsTr("Choose a wallpaper image")
    nameFilters: [qsTr("Images (*.jpg *.jpeg *.png *.gif *.bmp *.webp)"), qsTr("All files (*)")]
    onAccepted: {
      var path = page.pathFromUrl(selectedFile)
      if (path) page.image = path
    }
  }

  FolderDialog {
    id: directoryPicker

    objectName: "wallpaperDirectoryPicker"
    title: qsTr("Choose a wallpaper directory")
    onAccepted: {
      var path = page.pathFromUrl(selectedFolder)
      if (path) page.directory = path
    }
  }
}
