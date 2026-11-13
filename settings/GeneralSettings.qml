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

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.labelGap

    RowLayout {
      Layout.fillWidth: true

      Text {
        Layout.fillWidth: true
        text: "Dock size"
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: sizeSlider.liveValue + " / " + sizeSlider.maximum
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    PanelSlider {
      id: sizeSlider

      Layout.fillWidth: true
      value: page.dock.sizeLevel
      minimum: 1
      maximum: 5
      step: 1
      integer: true
      tickCount: 5
      trackColor: Style.normalFillFor(Commons.Color.popups.text, Commons.Color.accent)
      fillColor: Commons.Color.accent
      knobColor: Commons.Color.accent
      tickColor: Commons.Color.popups.background
      activeFocusOnTab: true
      Accessible.role: Accessible.Slider
      Accessible.name: "Dock size"
      Accessible.description: liveValue + " of " + maximum
      Accessible.onIncreaseAction: adjust(step)
      Accessible.onDecreaseAction: adjust(-step)
      Keys.onLeftPressed: adjust(-step)
      Keys.onRightPressed: adjust(step)
      Keys.onDownPressed: adjust(-step)
      Keys.onUpPressed: adjust(step)
      onReleased: function(level) {
        page.dock.setSizeLevel(level)
      }

      function adjust(delta) {
        page.dock.setSizeLevel(Math.max(minimum, Math.min(maximum, value + delta)))
      }

      BorderSurface {
        anchors.fill: parent
        visible: sizeSlider.activeFocus
        color: "transparent"
        radius: Style.cornerRadius
        borderSpec: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
      }
    }

    Binding {
      target: page.dock
      property: "previewSizeLevel"
      value: sizeSlider.liveValue
      when: sizeSlider.dragging
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
