import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var dock
  spacing: Style.spacing.lg

  Column {
    Layout.fillWidth: true
    spacing: Style.spacing.labelGap

    Text {
      text: "Dock position"
      color: Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }

    ButtonGroup {
      options: [
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" },
        { value: "left", label: "Left" },
        { value: "right", label: "Right" }
      ]
      value: page.dock.position
      foreground: Commons.Color.popups.text
      onChanged: function(position) {
        page.dock.setPosition(position)
      }
    }
  }

  Toggle {
    Layout.fillWidth: true
    label: "Auto-hide Dock"
    checked: page.dock.autohide
    foreground: Commons.Color.popups.text
    titleSize: Style.font.body
    onClicked: page.dock.setAutohide(!checked)
  }
}
