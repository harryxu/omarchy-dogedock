import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

FloatingWindow {
  id: panel

  required property var dock
  readonly property string label: "Settings"
  readonly property var groups: [
    { key: "general", label: "General", page: generalPage },
    { key: "extensions", label: qsTr("Extensions"), page: extensionsPage }
  ].concat(dock.extensions.settingsSources.filter(function(source) {
    return !!source.settingsPanel
  }).map(function(source) {
    return { key: "extension:" + source.reference, label: source.label, page: source.settingsPanel }
  }))
  property string selectedKey: "general"
  readonly property var currentGroup: groups.find(function(group) { return group.key === selectedKey }) || groups[1]

  onGroupsChanged: {
    if (selectedKey.startsWith("extension:") && !groups.some(function(group) { return group.key === selectedKey }))
      selectedKey = "extensions"
  }

  function open(screen) {
    if (panel.visible) return
    panel.screen = screen
    panel.visible = true
  }

  function close() {
    panel.visible = false
  }

  visible: false
  title: "DogeDock " + label
  implicitWidth: Math.max(Style.space(650), minimumSize.width)
  implicitHeight: Style.space(500)
  minimumSize: Qt.size(Style.space(420), Style.space(220))
  color: Commons.Color.popups.background
  onClosed: panel.close()
  onVisibleChanged: {
    if (visible && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) {
      resizeDelay.attempts = 6
      resizeDelay.restart()
    } else {
      resizeDelay.stop()
      findSettingsWindow.running = false
    }
  }

  Timer {
    id: resizeDelay
    property int attempts: 0

    // Let Omarchy apply its floating-workspace geometry before requesting ours.
    interval: 120
    onTriggered: {
      attempts--
      findSettingsWindow.running = true
    }
  }

  Process {
    id: findSettingsWindow

    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector { id: clients }

    onExited: function(exitCode) {
      if (exitCode !== 0 || !panel.visible) return
      var matches
      try {
        matches = JSON.parse(clients.text).filter(function(client) {
          return client.mapped && client.pid === Quickshell.processId && client.title === panel.title
        })
      } catch (error) {
        return
      }
      if (matches.length === 0) {
        if (resizeDelay.attempts > 0) resizeDelay.restart()
        return
      }
      if (matches.length !== 1) return
      var window = matches[0]
      var width = Math.round(panel.implicitWidth)
      var height = Math.round(panel.implicitHeight)
      if (!window.floating || window.fullscreen || !/^0x[0-9a-f]+$/i.test(window.address)
          || (window.size[0] === width && window.size[1] === height)) return

      var script = 'local window = hl.get_window("address:' + window.address + '")\n'
        + 'if window and window.mapped and window.floating and (window.fullscreen or 0) == 0 then\n'
        + '  hl.dispatch(hl.dsp.window.resize({window = window, relative = false, x = '
        + width + ', y = ' + height + '}))\nend'
      Quickshell.execDetached(["hyprctl", "eval", script])
    }
  }

  Component {
    id: generalPage

    GeneralSettings {
      dock: panel.dock
    }
  }

  Component {
    id: extensionsPage

    ExtensionSettings {
      dock: panel.dock
      onOpenSettingsPanel: function(reference) {
        panel.selectedKey = "extension:" + reference
      }
    }
  }

  FocusScope {
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: panel.close()

    RowLayout {
      anchors.fill: parent
      spacing: 0

      Flickable {
        id: sidebar
        Layout.fillHeight: true
        Layout.margins: Style.spacing.panelPadding
        Layout.preferredWidth: Style.space(132)
        clip: true
        contentWidth: width
        contentHeight: sidebarItems.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: sidebarItems
          width: sidebar.width
          spacing: Style.spacing.xs

          Repeater {
            model: panel.groups

            Button {
              required property var modelData

              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: modelData.label
              foreground: Commons.Color.popups.text
              leftAlign: true
              focusable: true
              selected: modelData.key === panel.currentGroup.key
              onClicked: panel.selectedKey = modelData.key
            }
          }
        }
      }

      Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: Style.spacing.hairline
        color: Util.alpha(Commons.Color.popups.text, 0.15)
      }

      ColumnLayout {
        Layout.minimumWidth: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Style.spacing.panelPadding
        spacing: Style.spacing.lg

        RowLayout {
          id: header

          Layout.alignment: Qt.AlignHCenter
          Layout.fillWidth: true
          Layout.maximumWidth: pageContent.width
          spacing: Style.spacing.md

          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: panel.currentGroup.label
            textFormat: Text.PlainText
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
          id: pageScroll
          Layout.minimumWidth: 0
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentWidth: width
          contentHeight: pageContent.height
          flickableDirection: Flickable.VerticalFlick
          boundsBehavior: Flickable.StopAtBounds

          Controls.ScrollBar.vertical: Controls.ScrollBar {
            id: pageScrollbar

            policy: pageScroll.contentHeight > pageScroll.height
              ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
            implicitWidth: Style.spacing.lg
            padding: Style.spacing.xxs

            contentItem: Rectangle {
              radius: width / 2
              color: Util.alpha(Commons.Color.popups.text, pageScrollbar.hovered || pageScrollbar.pressed ? 0.75 : 0.45)
            }
          }

          ColumnLayout {
            id: pageContent
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, Math.min(pageScroll.width - 2 * pageScrollbar.implicitWidth, Style.space(480)))

            Loader {
              id: pageLoader

              Layout.fillWidth: true
              Layout.minimumWidth: 0
              active: panel.visible || !panel.currentGroup.key.startsWith("extension:")
              sourceComponent: panel.currentGroup.page
              onSourceComponentChanged: pageScroll.contentY = 0
            }

            Text {
              Layout.fillWidth: true
              visible: pageLoader.status === Loader.Error
                || (pageLoader.status === Loader.Ready && !(pageLoader.item instanceof Item))
              text: qsTr("Could not open this extension’s settings page.")
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              color: Commons.Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
          }
        }
      }
    }
  }
}
