import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var dock
  readonly property bool compact: width < Style.space(300)
  spacing: compact ? Style.spacing.md : Style.spacing.lg

  component Label: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    textFormat: Text.PlainText
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.Wrap
  }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: Style.spacing.labelGap

    Label {
      text: qsTr("Dock position")
    }

    Flow {
      id: positionChoices

      readonly property int columns: page.compact ? 2 : 4
      readonly property real buttonWidth: Math.max(0, Math.floor((width - (columns - 1) * spacing) / columns))
      readonly property var options: [
        { value: "top", label: qsTr("Top") },
        { value: "bottom", label: qsTr("Bottom") },
        { value: "left", label: qsTr("Left") },
        { value: "right", label: qsTr("Right") }
      ]

      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: Style.spacing.md

      Repeater {
        id: positionButtons

        model: positionChoices.options

        Button {
          required property int index
          required property var modelData

          width: positionChoices.buttonWidth
          text: modelData.label
          foreground: Commons.Color.popups.text
          selected: page.dock.position === modelData.value
          bordered: true
          focusable: true
          Accessible.role: Accessible.RadioButton
          Accessible.name: text
          Accessible.checkable: true
          Accessible.checked: selected
          Accessible.onPressAction: clicked()
          KeyNavigation.left: positionButtons.itemAt(index - 1)
          KeyNavigation.right: positionButtons.itemAt(index + 1)
          KeyNavigation.up: page.compact ? positionButtons.itemAt(index - positionChoices.columns) : KeyNavigation.left
          KeyNavigation.down: page.compact ? positionButtons.itemAt(index + positionChoices.columns) : KeyNavigation.right
          onClicked: page.dock.setPosition(modelData.value)
        }
      }
    }
  }

  BorderSurface {
    id: sizeSurface

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.topMargin: page.compact ? Style.spacing.sm : Style.spacing.xxl
    padding: page.compact ? Style.spacing.md : Style.spacing.xxl
    implicitHeight: sizeFields.implicitHeight + contentTopInset + contentBottomInset
    color: Style.normalFillFor(Commons.Color.popups.text, Commons.Color.accent)
    borderSpec: Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
    radius: Style.cornerRadius

    ColumnLayout {
      id: sizeFields

      x: sizeSurface.contentLeftInset
      y: sizeSurface.contentTopInset
      width: Math.max(0, sizeSurface.width - x - sizeSurface.contentRightInset)
      spacing: Style.spacing.labelGap

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xs

        Label {
          text: qsTr("Dock size")
        }

        Label {
          Layout.fillWidth: false
          text: sizeSlider.liveValue + " / " + sizeSlider.maximum
        }
      }

      PanelSlider {
        id: sizeSlider

        Layout.fillWidth: true
        // Keep the enlarged hover knob inside the settings viewport at both ends.
        Layout.leftMargin: Style.spacing.xs
        Layout.rightMargin: Style.spacing.xs
        value: page.dock.sizeLevel
        minimum: 1
        maximum: page.dock.maxSizeLevel
        step: 1
        integer: true
        tickCount: maximum - minimum + 1
        trackColor: Style.normalFillFor(Commons.Color.popups.text, Commons.Color.accent)
        fillColor: Commons.Color.accent
        knobColor: Commons.Color.accent
        tickColor: Commons.Color.popups.background
        activeFocusOnTab: true
        Accessible.role: Accessible.Slider
        Accessible.name: qsTr("Dock size")
        Accessible.description: qsTr("%1 of %2").arg(liveValue).arg(maximum)
        Accessible.onIncreaseAction: adjust(step)
        Accessible.onDecreaseAction: adjust(-step)
        Keys.onLeftPressed: adjust(-step)
        Keys.onRightPressed: adjust(step)
        Keys.onDownPressed: adjust(-step)
        Keys.onUpPressed: adjust(step)
        onMoved: function(level) {
          page.dock.previewSizeLevel = level
        }
        onReleased: function(level) {
          page.dock.setSizeLevel(level)
          page.dock.previewSizeLevel = 0
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
    }
  }

  Connections {
    target: page.dock.settingsPanel

    function onVisibleChanged() {
      if (page.dock.settingsPanel.visible) return
      sizeSlider.dragging = false
      sizeSlider.liveValue = sizeSlider.value
      page.dock.previewSizeLevel = 0
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.xs

    Label {
      id: autoHideLabel

      text: qsTr("Auto-hide Dock")
    }

    ToggleSwitch {
      checked: page.dock.autohide
      foreground: Commons.Color.popups.text
      activeFocusOnTab: true
      hasCursor: activeFocus
      Accessible.role: Accessible.CheckBox
      Accessible.name: autoHideLabel.text
      Accessible.checkable: true
      Accessible.checked: checked
      Accessible.onPressAction: toggled()
      Keys.onReturnPressed: toggled()
      Keys.onEnterPressed: toggled()
      Keys.onSpacePressed: toggled()
      onToggled: page.dock.setAutohide(!checked)
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: Style.spacing.sm
    spacing: Style.spacing.md

    Text {
      text: qsTr("Appearance")
      color: Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      Accessible.role: Accessible.Heading
    }

    PanelSeparator {
      Layout.fillWidth: true
      foreground: Commons.Color.popups.text
      strength: 0.2
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.xs

    Label {
      id: cornerStyleLabel

      text: qsTr("Corner style")
    }

    Dropdown {
      id: cornerStyleDropdown

      objectName: "dockCornerStyle"
      Layout.fillWidth: false
      Layout.minimumWidth: 0
      Layout.preferredWidth: Style.space(page.compact ? 112 : 136)
      label: cornerStyleLabel.text
      showLabel: false
      options: [
        { value: "square", label: qsTr("Square") },
        { value: "rounded", label: qsTr("Rounded") }
      ]
      value: page.dock.cornerStyle
      Accessible.role: Accessible.ComboBox
      Accessible.name: label
      onChanged: function(style) {
        // Keep the trigger bound to the saved preference after Dropdown assigns its value.
        cornerStyleDropdown.value = Qt.binding(function() { return page.dock.cornerStyle })
        page.dock.setCornerStyle(style)
      }
    }
  }
}
