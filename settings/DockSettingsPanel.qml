import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

FloatingWindow {
  id: panel

  readonly property string label: "Settings"

  function open(screen) {
    if (panel.visible) return
    panel.screen = screen
    panel.visible = true
  }

  function close() {
    panel.visible = false
  }

  visible: false
  title: "DogeDock — " + label
  implicitWidth: Style.space(400)
  implicitHeight: Style.space(240)
  minimumSize: Qt.size(Style.space(240), Style.space(140))
  color: Commons.Color.popups.background
  onClosed: panel.close()

  FocusScope {
    anchors.fill: parent
    anchors.margins: Style.spacing.panelPadding
    focus: true
    Keys.onEscapePressed: panel.close()

    Text {
      anchors.left: parent.left
      anchors.right: closeButton.left
      anchors.rightMargin: Style.spacing.md
      anchors.verticalCenter: closeButton.verticalCenter
      text: panel.label
      color: Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      elide: Text.ElideRight
    }

    Button {
      id: closeButton
      anchors.top: parent.top
      anchors.right: parent.right
      focusable: true
      foreground: Commons.Color.popups.text
      text: "Close"
      onClicked: panel.close()
    }
  }
}
