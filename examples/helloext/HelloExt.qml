pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

QtObject {
  id: root

  required property var settings

  readonly property var icons: {
    var occurrences = new Map()
    return settings.names.filter(function(name) { return name.trim().length > 0 }).map(function(name) {
      var occurrence = occurrences.get(name) || 0
      occurrences.set(name, occurrence + 1)
      return {
        id: JSON.stringify([name, occurrence]),
        iconComponent: nameIcon,
        tooltip: name
      }
    })
  }

  property Component nameIcon: Component {
    Rectangle {
      id: tile

      required property var icon

      radius: Style.cornerRadius
      color: Commons.Color.accent

      Text {
        objectName: "helloInitial"
        anchors.fill: parent
        text: root.firstCharacter(tile.icon.tooltip.trim())
        textFormat: Text.PlainText
        color: Commons.Color.background
        font.family: Style.font.family
        font.pixelSize: Math.round(tile.height * 0.6)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
    }
  }

  function firstCharacter(name) {
    var first = name.charCodeAt(0)
    var second = name.charCodeAt(1)
    return name.slice(0, first >= 0xd800 && first <= 0xdbff && second >= 0xdc00 && second <= 0xdfff ? 2 : 1)
  }

  function iconClicked(iconId, button, anchor) {
    if (button !== "left") return
    var icon = icons.find(function(icon) { return icon.id === iconId })
    if (!icon) return
    if (anchor.current) {
      anchor.current.close()
      return
    }
    var view = anchor.show(greeting, { name: icon.tooltip }, {
      onOutsideClick: function(handle) { handle.close() }
    })
    if (view) view.item.dismiss = view.close
  }

  property Component greeting: Component {
    BorderSurface {
      id: popup

      required property string name
      property var dismiss

      implicitWidth: Style.space(280) + contentLeftInset + contentRightInset
      implicitHeight: content.implicitHeight + contentTopInset + contentBottomInset
      padding: Style.spacing.md
      radius: Style.cornerRadius
      color: Commons.Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)

      ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.leftMargin: popup.contentLeftInset
        anchors.rightMargin: popup.contentRightInset
        anchors.topMargin: popup.contentTopInset
        anchors.bottomMargin: popup.contentBottomInset
        spacing: Style.spacing.md

        Text {
          objectName: "helloGreeting"
          Layout.fillWidth: true
          text: qsTr("Hello %1").arg(popup.name)
          textFormat: Text.PlainText
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        Button {
          text: qsTr("Close")
          foreground: Commons.Color.popups.text
          focusable: true
          Accessible.name: text
          onClicked: if (popup.dismiss) popup.dismiss()
        }
      }
    }
  }
}
