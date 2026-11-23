pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BorderSurface {
  id: menu

  required property bool canEmpty
  property var dismiss
  signal openRequested()
  signal emptyRequested(string screenName)

  implicitWidth: Style.space(218) + contentLeftInset + contentRightInset
  implicitHeight: actions.implicitHeight + contentTopInset + contentBottomInset
  radius: Style.cornerRadius
  padding: Style.spacing.sm
  color: Commons.Color.popups.background
  borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)

  Column {
    id: actions

    x: menu.contentLeftInset
    y: menu.contentTopInset
    width: menu.width - menu.contentLeftInset - menu.contentRightInset

    Button {
      width: parent.width
      height: Style.spacing.popupRowHeight
      leftAlign: true
      text: qsTr("Open")
      foreground: Commons.Color.popups.text
      onClicked: {
        menu.openRequested()
        menu.dismiss()
      }
    }

    Button {
      width: parent.width
      height: Style.spacing.popupRowHeight
      leftAlign: true
      enabled: menu.canEmpty
      opacity: enabled ? 1 : 0.45
      text: qsTr("Empty Trash…")
      foreground: Commons.Color.popups.text
      onClicked: {
        if (!enabled) return
        var screenName = menu.Screen.name
        menu.dismiss()
        menu.emptyRequested(screenName)
      }
    }
  }
}
