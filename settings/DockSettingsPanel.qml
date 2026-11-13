import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

FloatingWindow {
  id: panel

  required property var dock
  readonly property string label: "Settings"
  readonly property var groups: [{ label: "General", page: generalPage }]
  property int selectedGroup: 0

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
  implicitWidth: Math.max(Style.space(560), minimumSize.width)
  implicitHeight: Style.space(320)
  minimumSize: Qt.size(Math.ceil(sidebar.Layout.preferredWidth + Style.spacing.hairline
    + Style.spacing.panelPadding * 4 + Math.max(header.implicitWidth, pageLoader.implicitWidth)), Style.space(220))
  color: Commons.Color.popups.background
  onClosed: panel.close()

  Component {
    id: generalPage

    GeneralSettings {
      dock: panel.dock
    }
  }

  FocusScope {
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: panel.close()

    RowLayout {
      anchors.fill: parent
      spacing: 0

      ColumnLayout {
        id: sidebar

        Layout.alignment: Qt.AlignTop
        Layout.margins: Style.spacing.panelPadding
        Layout.preferredWidth: Math.max(Style.space(112), implicitWidth)
        Layout.maximumWidth: Layout.preferredWidth
        spacing: Style.spacing.xs

        Repeater {
          model: panel.groups

          Button {
            required property int index
            required property var modelData

            Layout.fillWidth: true
            text: modelData.label
            foreground: Commons.Color.popups.text
            leftAlign: true
            focusable: true
            selected: index === panel.selectedGroup
            onClicked: panel.selectedGroup = index
          }
        }
      }

      Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: Style.spacing.hairline
        color: Util.alpha(Commons.Color.popups.text, 0.15)
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.spacing.panelPadding
        spacing: Style.spacing.lg

        RowLayout {
          id: header

          Layout.fillWidth: true
          spacing: Style.spacing.md

          Text {
            Layout.fillWidth: true
            text: panel.groups[panel.selectedGroup].label
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Button {
            focusable: true
            foreground: Commons.Color.popups.text
            text: "Close"
            onClicked: panel.close()
          }
        }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentWidth: width
          contentHeight: pageLoader.height
          flickableDirection: Flickable.VerticalFlick
          boundsBehavior: Flickable.StopAtBounds

          Loader {
            id: pageLoader

            width: parent.width
            sourceComponent: panel.groups[panel.selectedGroup].page
          }
        }
      }
    }
  }
}
