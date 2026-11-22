pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BorderSurface {
  id: menu

  required property var wallpaper
  property var openSettings
  property var dismiss
  readonly property bool dialogOpen: currentWallpaper.running || imagePicker.visible || directoryPicker.visible || savePicker.visible
  readonly property var menuActions: {
    var settings = wallpaper.config
    var idle = !wallpaper.busy && !dialogOpen
    var actions = settings.mode === "directory" ? [
      { id: "directory", text: qsTr("Change directory…"), enabled: idle },
      { id: "open", text: qsTr("Open directory"), enabled: !dialogOpen && !wallpaper.menuBusy && !!settings.directory },
      { id: "filename", text: qsTr("By filename"), enabled: idle, checked: settings.order === "filename" },
      { id: "random", text: qsTr("Random"), enabled: idle, checked: settings.order === "random" }
    ] : [{ id: "image", text: qsTr("Change wallpaper…"), enabled: idle }]
    actions.push({ id: "export", text: qsTr("Save wallpaper as…"), enabled: idle && !wallpaper.menuBusy })
    if (openSettings) actions.push({ id: "settings", text: qsTr("Settings"), enabled: !dialogOpen })
    return actions
  }

  radius: Style.cornerRadius
  color: Commons.Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
  padding: Style.spacing.sm
  implicitWidth: Style.space(276) + contentLeftInset + contentRightInset
  implicitHeight: menuActions.length * Style.spacing.popupRowHeight + contentTopInset + contentBottomInset

  function activateAction(id) {
    var action = menuActions.find(function(entry) { return entry.id === id })
    if (!action || !action.enabled) return
    switch (id) {
      case "image": imagePicker.open(); return
      case "directory": directoryPicker.open(); return
      case "export": currentWallpaper.running = true; return
      case "settings": openSettings(); return
      case "open": wallpaper.openDirectory(); break
      case "filename":
      case "random":
        if (wallpaper.config.order !== id) wallpaper.savePreferences({ order: id }, true)
        break
    }
    dismiss()
  }

  ListView {
    id: rows

    x: menu.contentLeftInset
    y: menu.contentTopInset
    width: Math.max(0, menu.width - x - menu.contentRightInset)
    height: Math.max(0, menu.height - y - menu.contentBottomInset)
    model: menu.menuActions
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    delegate: Button {
      required property var modelData

      width: rows.width
      height: Style.spacing.popupRowHeight
      text: modelData.text
      enabled: modelData.enabled
      selected: modelData.checked === true
      leftAlign: true
      foreground: Commons.Color.popups.text
      verticalPadding: 0
      Accessible.role: modelData.checked === undefined ? Accessible.MenuItem : Accessible.RadioButton
      Accessible.name: text
      Accessible.checkable: modelData.checked !== undefined
      Accessible.checked: selected
      Accessible.onPressAction: if (enabled) clicked()
      onClicked: menu.activateAction(modelData.id)
    }
  }

  FileDialog {
    id: imagePicker

    objectName: "wallpaperMenuImagePicker"
    title: qsTr("Choose a wallpaper image")
    nameFilters: [qsTr("Images (*.jpg *.jpeg *.png *.gif *.bmp *.webp)"), qsTr("All files (*)")]
    currentFolder: {
      var path = menu.wallpaper.config.image
      return path ? Commons.Util.fileUrl(path.slice(0, path.lastIndexOf("/") + 1)) : ""
    }
    popupType: Controls.Popup.Window
    onAccepted: {
      var path = menu.wallpaper.pathFromUrl(selectedFile)
      if (path) menu.wallpaper.save({ mode: "single", image: path }, true)
      menu.dismiss()
    }
    onRejected: menu.dismiss()
  }

  FolderDialog {
    id: directoryPicker

    objectName: "wallpaperMenuDirectoryPicker"
    title: qsTr("Choose a wallpaper directory")
    currentFolder: Commons.Util.fileUrl(menu.wallpaper.config.directory)
    popupType: Controls.Popup.Window
    onAccepted: {
      var path = menu.wallpaper.pathFromUrl(selectedFolder)
      if (path) menu.wallpaper.save({ mode: "directory", directory: path }, true)
      menu.dismiss()
    }
    onRejected: menu.dismiss()
  }

  FileDialog {
    id: savePicker

    property string sourcePath: ""

    objectName: "wallpaperMenuSavePicker"
    title: qsTr("Save wallpaper as")
    fileMode: FileDialog.SaveFile
    popupType: Controls.Popup.Window
    onAccepted: {
      var path = menu.wallpaper.pathFromUrl(selectedFile)
      if (path) menu.wallpaper.exportWallpaper(sourcePath, path)
      menu.dismiss()
    }
    onRejected: menu.dismiss()
  }

  Process {
    id: currentWallpaper

    command: ["/usr/bin/python", menu.wallpaper.helper, "current"]
    stdout: StdioCollector { id: currentOutput }
    onExited: function(exitCode, exitStatus) {
      var path = ""
      if (exitCode === 0 && exitStatus === 0) {
        try { path = menu.wallpaper.localPath(JSON.parse(currentOutput.text)) } catch (error) {}
      }
      if (!path) {
        menu.wallpaper.notifyFailure(qsTr("The current wallpaper file could not be found."))
        menu.dismiss()
        return
      }
      var filename = path.slice(path.lastIndexOf("/") + 1)
      var dot = filename.lastIndexOf(".")
      savePicker.sourcePath = path
      savePicker.defaultSuffix = dot > 0 ? filename.slice(dot + 1) : ""
      savePicker.selectedFile = Commons.Util.fileUrl(path)
      savePicker.open()
    }
  }
}
