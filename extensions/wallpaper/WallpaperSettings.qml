pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

ColumnLayout {
  id: page

  required property var wallpaper
  readonly property bool directoryMode: mode === "directory"
  readonly property bool compact: width < Style.space(300)
  readonly property string selectedPath: directoryMode ? directory : image
  readonly property bool validInterval: /^\d+$/.test(minutesField.text) && minutesField.acceptableInput
  property string mode: "single"
  property string image: ""
  property string directory: ""
  property string order: "filename"
  property var loadedConfig: null

  spacing: compact ? Style.spacing.md : Style.spacing.lg

  function loadDraft() {
    var saved = wallpaper.config
    if (!loadedConfig || mode === loadedConfig.mode) mode = saved.mode
    if (!loadedConfig || image === loadedConfig.image) image = saved.image
    if (!loadedConfig || directory === loadedConfig.directory) directory = saved.directory
    if (!loadedConfig || order === loadedConfig.order) order = saved.order
    if (!loadedConfig || minutesField.text === String(loadedConfig.minutes)) minutesField.text = String(saved.minutes)
    loadedConfig = saved
  }

  function apply() {
    if (!applyButton.enabled) return
    wallpaper.save({
      mode: mode, image: image, directory: directory, order: order,
      minutes: validInterval ? Number(minutesField.text) : wallpaper.config.minutes
    })
  }

  function pathFromUrl(url) {
    return wallpaper.pathFromUrl(url)
  }

  Component.onCompleted: loadDraft()
  Connections {
    target: page.wallpaper
    function onConfigChanged() { page.loadDraft() }
  }

  component Label: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    textFormat: Text.PlainText
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.Wrap
  }

  Flow {
    id: modeTabs

    readonly property real tabWidth: Math.floor(page.compact ? width
      : (width - spacing) / 2)
    readonly property var options: [
      { value: "single", label: qsTr("Single image"), icon: "\uf03e" },
      { value: "directory", label: qsTr("Directory rotation"), icon: "\uf021" }
    ]

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: Style.spacing.md
    enabled: page.wallpaper.ready && !page.wallpaper.busy

    Repeater {
      id: modeButtons

      model: modeTabs.options

      Button {
        required property int index
        required property var modelData

        width: modeTabs.tabWidth
        text: modelData.label
        iconText: modelData.icon
        foreground: Commons.Color.popups.text
        selected: page.mode === modelData.value
        bordered: true
        focusable: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.checkable: true
        Accessible.checked: selected
        Accessible.onPressAction: if (enabled) clicked()
        KeyNavigation.left: modeButtons.itemAt(index - 1)
        KeyNavigation.right: modeButtons.itemAt(index + 1)
        KeyNavigation.up: KeyNavigation.left
        KeyNavigation.down: KeyNavigation.right
        onClicked: page.mode = modelData.value
      }
    }
  }

  BorderSurface {
    id: settingsSurface

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.topMargin: page.compact ? Style.spacing.sm : Style.spacing.xxl
    padding: page.compact ? Style.spacing.md : Style.spacing.xxl
    implicitHeight: settingsFields.implicitHeight + contentTopInset + contentBottomInset
    color: Style.normalFillFor(Commons.Color.popups.text, Commons.Color.accent)
    borderSpec: Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
    radius: Style.cornerRadius

    ColumnLayout {
      id: settingsFields

      x: settingsSurface.contentLeftInset
      y: settingsSurface.contentTopInset
      width: Math.max(0, settingsSurface.width - x - settingsSurface.contentRightInset)
      spacing: Style.spacing.lg

      GridLayout {
        id: sourcePicker

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        columns: width >= chooseButton.implicitWidth + columnSpacing + Style.space(140) ? 2 : 1
        columnSpacing: Style.spacing.xs
        rowSpacing: Style.spacing.xs

        BorderSurface {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          implicitHeight: Math.max(chooseButton.implicitHeight, pathLabel.implicitHeight + Style.spacing.controlPaddingY * 2)
          color: Style.normalFillFor(Commons.Color.popups.text, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
          radius: Style.cornerRadius

          Text {
            id: pathLabel

            anchors.fill: parent
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.rightMargin: Style.spacing.controlPaddingX
            verticalAlignment: Text.AlignVCenter
            text: page.selectedPath || (page.directoryMode ? qsTr("No directory selected") : qsTr("No image selected"))
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          HoverHandler { id: sourceHover }

          PanelToolTip {
            visible: sourceHover.hovered && !!page.selectedPath && pathLabel.truncated
            text: page.selectedPath
            width: Math.min(implicitWidth, page.width)
          }
        }

        Button {
          id: chooseButton

          Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
          Layout.fillWidth: sourcePicker.columns === 1
          Layout.minimumWidth: 0
          text: page.directoryMode ? qsTr("Choose directory…") : qsTr("Choose image…")
          foreground: Commons.Color.popups.text
          background: Style.normalFillFor(foreground, accent)
          bordered: true
          focusable: true
          enabled: page.wallpaper.ready && !page.wallpaper.busy
          onClicked: {
            if (page.directoryMode) directoryPicker.open()
            else imagePicker.open()
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: page.compact ? 0 : Style.spacing.sm
        visible: page.directoryMode
        spacing: Style.spacing.xs

        Label {
          text: qsTr("Interval (minutes)")
        }

        TextField {
          id: minutesField

          Layout.fillWidth: false
          Layout.preferredWidth: Style.space(page.compact ? 60 : 72)
          enabled: page.wallpaper.ready && !page.wallpaper.busy
          foreground: Commons.Color.popups.text
          Accessible.name: qsTr("Interval (minutes)")
          validator: IntValidator { bottom: 1; top: 1440 }
          inputMethodHints: Qt.ImhDigitsOnly
          onAccepted: page.apply()
        }
      }

      Label {
        visible: page.directoryMode && !page.validInterval
        text: qsTr("Enter an interval from 1 to 1440 minutes.")
        color: Commons.Color.urgent
      }

      RowLayout {
        Layout.fillWidth: true
        visible: page.directoryMode
        spacing: Style.spacing.xs

        Label {
          text: qsTr("Order")
        }

        Dropdown {
          objectName: "wallpaperRotationOrder"
          Layout.fillWidth: false
          Layout.minimumWidth: 0
          Layout.preferredWidth: Style.space(136)
          label: qsTr("Order")
          showLabel: false
          Accessible.name: label
          enabled: page.wallpaper.ready && !page.wallpaper.busy
          options: [
            { value: "filename", label: qsTr("By filename") },
            { value: "random", label: qsTr("Random") }
          ]
          value: page.order
          onChanged: function(selection) {
            page.order = selection
            value = Qt.binding(function() { return page.order })
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.topMargin: Style.spacing.sm
        visible: page.directoryMode
        enabled: page.wallpaper.canStep && page.directory === page.wallpaper.config.directory
        columns: width >= 2 * Math.max(previousButton.implicitWidth, nextButton.implicitWidth) + columnSpacing ? 2 : 1
        uniformCellWidths: true
        columnSpacing: Style.spacing.xs
        rowSpacing: Style.spacing.xs

        Button {
          id: previousButton

          Layout.fillWidth: true
          Layout.minimumWidth: 0
          text: qsTr("Previous")
          iconText: "\uf053"
          foreground: Commons.Color.popups.text
          bordered: true
          focusable: true
          Accessible.role: Accessible.Button
          Accessible.name: qsTr("Previous wallpaper")
          Accessible.onPressAction: if (enabled) clicked()
          onClicked: page.wallpaper.step(-1)
        }

        Button {
          id: nextButton

          Layout.fillWidth: true
          Layout.minimumWidth: 0
          text: qsTr("Next")
          iconText: "\uf054"
          foreground: Commons.Color.popups.text
          bordered: true
          focusable: true
          Accessible.role: Accessible.Button
          Accessible.name: qsTr("Next wallpaper")
          Accessible.onPressAction: if (enabled) clicked()
          onClicked: page.wallpaper.step(1)
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.xs

    Label {
      text: qsTr("Show icon in Dock")
    }

    ToggleSwitch {
      objectName: "wallpaperDockIconSwitch"
      checked: page.wallpaper.config.showDockIcon
      enabled: page.wallpaper.ready && !page.wallpaper.busy
      foreground: Commons.Color.popups.text
      activeFocusOnTab: true
      hasCursor: activeFocus
      Accessible.role: Accessible.CheckBox
      Accessible.name: qsTr("Show icon in Dock")
      Accessible.checkable: true
      Accessible.checked: checked
      Accessible.onPressAction: if (enabled) toggled()
      Keys.onReturnPressed: toggled()
      Keys.onEnterPressed: toggled()
      Keys.onSpacePressed: toggled()
      onToggled: page.wallpaper.savePreferences({ showDockIcon: !checked })
    }
  }

  Button {
    id: applyButton

    Layout.alignment: Qt.AlignLeft
    Layout.topMargin: page.compact ? Style.spacing.xl : Style.spacing.huge
    text: qsTr("Apply")
    foreground: Commons.Color.popups.text
    background: enabled ? Style.selectedAccentFill : "transparent"
    bordered: true
    focusable: true
    enabled: page.wallpaper.ready && !page.wallpaper.busy && !!page.selectedPath
      && (!page.directoryMode || page.validInterval)
    onClicked: page.apply()
  }

  Label {
    visible: page.wallpaper.busy || text.length > 0
    text: page.wallpaper.busy ? qsTr("Applying wallpaper…") : page.wallpaper.error
    color: page.wallpaper.busy ? Commons.Color.popups.text : Commons.Color.urgent
  }

  FileDialog {
    id: imagePicker

    objectName: "wallpaperImagePicker"
    title: qsTr("Choose a wallpaper image")
    nameFilters: [qsTr("Images (*.jpg *.jpeg *.png *.gif *.bmp *.webp)"), qsTr("All files (*)")]
    onAccepted: {
      var path = page.pathFromUrl(selectedFile)
      if (path) page.image = path
    }
  }

  FolderDialog {
    id: directoryPicker

    objectName: "wallpaperDirectoryPicker"
    title: qsTr("Choose a wallpaper directory")
    onAccepted: {
      var path = page.pathFromUrl(selectedFolder)
      if (path) page.directory = path
    }
  }
}
