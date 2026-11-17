pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import Quickshell.Io

BorderSurface {
  id: menu

  required property string rootPath
  required property var openPath
  required property bool contextMenu
  property var dismiss

  radius: Style.cornerRadius
  color: Commons.Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
  padding: Style.spacing.sm
  implicitWidth: Style.space(contextMenu ? 218 : 320) + contentLeftInset + contentRightInset
  implicitHeight: menuActions.length * Style.spacing.popupRowHeight + contentTopInset + contentBottomInset

  readonly property int scrollHintSize: Style.space(16)
  readonly property int hintBand: implicitHeight > height ? scrollHintSize : 0

  onMenuActionsChanged: Qt.callLater(directoryList.positionViewAtBeginning)

  function activateAction(id) {
    var action = menuActions.find(function(entry) { return entry.id === id })
    if (action && action.enabled !== false && !triggerAction(id) && dismiss) dismiss()
  }
  property var pathStack: [rootPath]
  readonly property string currentPath: pathStack[pathStack.length - 1]
  property var entries: []
  property bool loading: true
  property string loadError: ""
  readonly property string listingScript: decodeURIComponent(String(Qt.resolvedUrl("FolderEntries.py")).slice("file://".length))
  readonly property var menuActions: {
    if (contextMenu) return [{ id: "open", text: qsTr("Open") }]
    var actions = [{ id: "open", text: qsTr("Open Current Folder"), iconName: "folder-open" }]
    if (pathStack.length > 1) actions.push({ id: "back", text: qsTr("Back"), iconName: "go-up-symbolic", enabled: !loading })
    if (loading || loadError || !entries.length) {
      actions.push({
        id: "status",
        text: loading ? qsTr("Loading…") : loadError || qsTr("This folder is empty."),
        enabled: false
      })
    } else {
      entries.forEach(function(entry, index) {
        actions.push({ id: String(index), text: entry.name, iconName: entry.directory ? "folder" : "text-x-generic" })
      })
    }
    return actions
  }

  Component.onCompleted: if (!contextMenu) listing.running = true

  function navigate(next) {
    loading = true
    loadError = ""
    entries = []
    pathStack = next
    listing.running = true
  }

  function triggerAction(id) {
    if (id === "open") {
      openPath(currentPath, true)
      return false
    }
    if (loading) return true
    if (id === "back" && pathStack.length > 1) {
      navigate(pathStack.slice(0, -1))
      return true
    }
    var entry = entries[Number(id)]
    if (!entry) return true
    var path = (currentPath === "/" ? currentPath : currentPath + "/") + entry.name
    if (entry.directory) {
      navigate(pathStack.concat([path]))
      return true
    }
    openPath(path, false)
    return false
  }

  property Process listing: Process {
    command: ["/usr/bin/python", menu.listingScript, menu.currentPath]
    stdout: StdioCollector { id: output }

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && exitStatus === 0) {
        try {
          menu.entries = JSON.parse(output.text)
        } catch (error) {
          menu.loadError = qsTr("Could not read this folder.")
        }
      } else {
        menu.loadError = qsTr("Could not read this folder.")
      }
      menu.loading = false
    }
  }

  MenuRow {
    id: topActionRow

    readonly property var action: menu.menuActions[0]

    x: menu.contentLeftInset
    y: menu.contentTopInset
    width: menu.width - menu.contentLeftInset - menu.contentRightInset
    visible: !!action
    enabled: !!action && action.enabled !== false
    text: action ? action.text : ""
    iconName: action ? action.iconName || "" : ""
    onTriggered: if (action) menu.activateAction(action.id)
  }

  ListView {
    id: directoryList

    objectName: "extensionBrowseViewport"

    visible: !menu.contextMenu
    x: menu.contentLeftInset
    y: menu.contentTopInset + topActionRow.height + menu.hintBand
    width: topActionRow.width
    height: Math.max(0, menu.height - y - menu.contentBottomInset - menu.hintBand)
    model: menu.menuActions.slice(1)
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    delegate: MenuRow {
      required property var modelData

      width: directoryList.width
      text: modelData.text
      iconName: modelData.iconName || ""
      enabled: modelData.enabled !== false
      onTriggered: menu.activateAction(modelData.id)
    }
  }

  ScrollHint {
    objectName: "extensionBrowseScrollUp"
    anchors.horizontalCenter: directoryList.horizontalCenter
    anchors.bottom: directoryList.top
    rotation: 180
    visible: menu.hintBand > 0 && !directoryList.atYBeginning
  }

  ScrollHint {
    objectName: "extensionBrowseScrollDown"
    anchors.horizontalCenter: directoryList.horizontalCenter
    anchors.top: directoryList.bottom
    visible: menu.hintBand > 0 && !directoryList.atYEnd
  }

  component ScrollHint: Shape {
    id: hint

    width: menu.scrollHintSize
    height: width
    antialiasing: true

    ShapePath {
      strokeColor: Commons.Color.popups.text
      strokeWidth: Style.spacing.hairline
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: hint.width * 0.25
      startY: hint.height * 0.4

      PathLine { x: hint.width * 0.5; y: hint.height * 0.65 }
      PathLine { x: hint.width * 0.75; y: hint.height * 0.4 }
    }
  }

  component MenuRow: Rectangle {
    id: row

    property string text: ""
    property string iconName: ""
    signal triggered()

    width: parent ? parent.width : 0
    height: visible ? Style.spacing.popupRowHeight : 0
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Style.hoverFill : "transparent"

    Image {
      id: rowIcon

      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.controlPaddingX
      width: Style.space(16)
      height: width
      sourceSize: Qt.size(width, height)
      source: row.iconName ? Quickshell.iconPath(row.iconName, true) : ""
      visible: status === Image.Ready
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.controlPaddingX + (rowIcon.visible ? rowIcon.width + Style.spacing.xs : 0)
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.controlPaddingX
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: row.text
      color: Commons.Color.popups.text
      opacity: row.enabled ? 1 : 0.5
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.triggered()
    }
  }
}
