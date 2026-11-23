pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

PanelWindow {
  id: dialog

  property ShellScreen targetScreen: null
  signal accepted()

  function dismiss() { targetScreen = null }

  screen: targetScreen
  visible: !!targetScreen
  implicitWidth: Math.min(Style.space(370), targetScreen ? targetScreen.width : Style.space(370))
  implicitHeight: Math.ceil(layout.implicitHeight + card.contentTopInset + card.contentBottomInset)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dogedock-trash-confirmation"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  onVisibleChanged: if (visible) cancelButton.forceActiveFocus()

  HyprlandFocusGrab {
    active: dialog.visible
    windows: [dialog]
    onCleared: dialog.dismiss()
  }

  BorderSurface {
    id: card

    anchors.fill: parent
    color: Util.alpha(Commons.Color.popups.background, 1)
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
    padding: Style.space(18)
    radius: Style.cornerRadius
    LayoutMirroring.enabled: Commons.I18n.rightToLeft
    LayoutMirroring.childrenInherit: true

    Keys.onEscapePressed: dialog.dismiss()

    ColumnLayout {
      id: layout

      anchors.fill: parent
      anchors.leftMargin: card.contentLeftInset
      anchors.rightMargin: card.contentRightInset
      anchors.topMargin: card.contentTopInset
      anchors.bottomMargin: card.contentBottomInset
      spacing: Style.spacing.md

      Text {
        Layout.fillWidth: true
        text: qsTr("Empty Trash?")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        text: qsTr("All items in the Trash will be permanently deleted.")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Style.spacing.sm

        Button {
          id: cancelButton

          text: Commons.I18n.t("common.cancel")
          foreground: Commons.Color.popups.text
          bordered: true
          focusable: true
          KeyNavigation.left: emptyButton
          KeyNavigation.right: emptyButton
          onClicked: dialog.dismiss()
        }

        Button {
          id: emptyButton

          text: qsTr("Empty Trash")
          foreground: Commons.Color.urgent
          accent: Commons.Color.urgent
          bordered: true
          focusable: true
          KeyNavigation.left: cancelButton
          KeyNavigation.right: cancelButton
          onClicked: {
            if (!dialog.visible) return
            dialog.dismiss()
            dialog.accepted()
          }
        }
      }
    }
  }
}
