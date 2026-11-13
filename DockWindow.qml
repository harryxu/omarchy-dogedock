import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel

// One screen's dock. It stays mapped across workspace changes and limits
// input to its visible contents and the auto-hide trigger.
PanelWindow {
  id: window
  // Right-to-left languages read this window mirrored.
  Binding { target: window.contentItem; property: "LayoutMirroring.enabled"; value: Commons.I18n.rightToLeft }
  Binding { target: window.contentItem; property: "LayoutMirroring.childrenInherit"; value: true }


  property var dock: null

  readonly property string position: dock ? dock.position : "bottom"
  readonly property bool vertical: dock ? dock.vertical : false
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property var workspace: monitor ? monitor.activeWorkspace : null
  readonly property int workspaceId: workspace ? workspace.id : -1
  // The most fullscreen window on the workspace, as Hyprland counts it: 1 is
  // maximized, and 2 or 3 fullscreen.
  readonly property int fullscreenMode: {
    var mode = 0
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      if (!toplevel.workspace || toplevel.workspace.id !== workspaceId) continue
      var ipc = toplevel.lastIpcObject
      mode = Math.max(mode, ipc && ipc.fullscreen ? ipc.fullscreen : 0)
    }
    return mode
  }
  readonly property bool shown: !!dock && !!workspace && fullscreenMode < 2
  // With auto-hide on, the dock waits off screen until the pointer reaches its
  // edge, and stays while the pointer, a menu, or a drag still needs it.
  readonly property bool autohide: !!dock && dock.autohide
  property bool revealed: false
  readonly property bool menuOpen: menuItem !== null || settingsMenu || menuExtensionId.length > 0
  readonly property bool settingsOpen: !!dock && dock.settingsPanel.visible && dock.settingsPanel.screen === screen
  readonly property bool tucked: autohide && !(revealed || menuOpen || settingsOpen || dragging || insertIndex >= 0 || fileDrop.active)
  readonly property bool contentShown: shown && !tucked

  readonly property real sizeScale: dock ? ((dock.previewSizeLevel || dock.sizeLevel) + 7) / 10 : 1
  readonly property int gap: scaled(Style.spacing.xs)
  readonly property int edgeInset: Math.max(gap, scaled(Style.spacing.lg))
  readonly property int platePadding: scaled(Style.space(7))
  readonly property int iconSize: scaled(36 * Style.fontScale)
  readonly property int indicatorSize: scaled(Math.max(3, Style.space(4)))
  readonly property int indicatorGap: scaled(Math.max(2, Style.spacing.xs))
  readonly property int iconInset: scaled(Style.spacing.md)
  readonly property int slotSize: iconSize + iconInset * 2
  readonly property int dockDepth: slotSize + platePadding * 2
  readonly property int appSlotsLength: (appRepeater.count + 1) * slotSize
  readonly property int dividerSpace: extensionRepeater.count > 0 ? 2 * gap + 1 : 0
  // Room inward of the dock for the apps button's six menu rows.
  readonly property int popupRoom: Style.spacing.popupRowHeight * 6 + Style.spacing.sm * 2 + Style.normalBorderWidth * 2 + gap * 2

  function scaled(pixels) {
    return Math.round(pixels * window.sizeScale)
  }
  // Icons pop away from the screen edge.
  readonly property int popOrigin: position === "top" ? Item.Top
    : position === "left" ? Item.Left
    : position === "right" ? Item.Right
    : Item.Bottom

  // The app being dragged along the dock, how far the pointer has taken it,
  // and the slot it would land in.
  property int dragIndex: -1
  property int dropIndex: -1
  property real dragOffset: 0
  readonly property bool dragging: dragIndex >= 0
  // Off while a drop resets the slots: they snap to where the reorder puts
  // them rather than sliding back from where they stepped aside. Set before
  // the drag state changes, so the slots never see the reset animated.
  property bool animateShifts: true
  // Where an app dragged in from the app grid would land, or -1.
  property int insertIndex: -1

  // The app grid reports screen-local points. Use the compositor's placement
  // because the Dock can share an edge with other exclusive surfaces.
  function origin() {
    var layers = dock && dock.dockLayers[screen.name]
    var layer = layers && (layers.levels[WlrLayer.Top] || []).find(function(entry) {
      return entry.namespace === window.WlrLayershell.namespace
    })
    if (layer) return Qt.point(layer.x - screen.x, layer.y - screen.y)

    // Before the layer query returns, estimate the origin from the reserved
    // edges. The reported reservation includes the Dock's own exclusive zone.
    var reserved = monitor && monitor.lastIpcObject && monitor.lastIpcObject.reserved ? monitor.lastIpcObject.reserved : [0, 0, 0, 0]
    var edge = ["left", "top", "right", "bottom"].indexOf(window.position)
    var offset = function(i) { return Math.max(0, (reserved[i] || 0) - (i === edge ? window.exclusiveZone : 0)) }
    var x = window.position === "right" ? screen.width - offset(2) - window.width : offset(0)
    var y = window.position === "bottom" ? screen.height - offset(3) - window.height : offset(1)
    return Qt.point(x, y)
  }

  // An app from the app grid lands where the pointer is, once it is over the
  // dock or close to it on the inward side.
  function moveExternalDrag(screenX, screenY) {
    var at = window.origin()
    var point = Qt.point(screenX - at.x - body.x, screenY - at.y - body.y)
    var reach = window.slotSize
    var along = window.vertical ? point.y : point.x
    var across = window.vertical ? point.x : point.y
    var appEnd = (window.vertical ? slots.y : slots.x) + window.appSlotsLength
    var end = window.dividerSpace > 0 ? appEnd + window.dividerSpace
      : (window.vertical ? body.height : body.width) + reach
    var depth = window.vertical ? body.width : body.height
    var near = along >= -reach && along <= end && across >= -reach && across <= depth + reach
    if (window.shown && window.autohide && near) window.revealed = true
    window.insertIndex = window.shown && near ? window.slotIndexAt(point) : -1
  }

  function dropExternalDrag(screenX, screenY, key) {
    window.moveExternalDrag(screenX, screenY)
    window.settleShifts()
    if (window.insertIndex >= 0 && key && window.dock) window.dock.pinAt(key, window.insertIndex)
    window.endExternalDrag()
  }

  function endExternalDrag() {
    window.insertIndex = -1
    if (window.autohide) hideTimer.restart()
  }

  // The slot a point along the dock falls before, counting from the first app.
  function slotIndexAt(point) {
    var along = window.vertical ? point.y : point.x
    var first = (window.vertical ? slots.y : slots.x) + window.slotSize
    var count = window.dock ? window.dock.itemModel.count : 0
    return Math.max(0, Math.min(count, Math.round((along - first) / window.slotSize)))
  }

  function fileDropSlotAt(x, y) {
    var slotX = x - body.x - slots.x
    var slotY = y - body.y - slots.y
    var across = window.vertical ? slotX : slotY
    if (across < 0 || across >= window.slotSize) return null
    var along = window.vertical ? slotY : slotX
    if (along < window.slotSize) return null
    if (along < window.appSlotsLength) return appRepeater.itemAt(Math.floor(along / window.slotSize) - 1)
    var extensionOffset = along - window.appSlotsLength - window.dividerSpace
    return extensionOffset >= 0 ? extensionRepeater.itemAt(Math.floor(extensionOffset / window.slotSize)) : null
  }

  property var menuItem: null
  property Item menuSlot: null
  property string menuExtensionId: ""
  property var menuExtension: null
  property var confirmation: null
  readonly property var extensionActions: dock ? dock.extensions.actionsFor(menuExtension) : []
  // The apps button's menu: where the dock sits and whether it hides.
  property bool settingsMenu: false

  onExtensionActionsChanged: Qt.callLater(checkExtensionMenu)

  Connections {
    target: window.dock ? window.dock.extensions : null
    function onInstancesChanged() { window.checkExtensionMenu() }
  }

  onShownChanged: {
    if (shown) return
    closeMenu()
    window.revealed = false
  }

  function openMenu(item, slot) {
    window.closeMenu()
    window.menuItem = item
    window.menuSlot = slot
  }

  function openSettingsMenu(slot) {
    window.closeMenu()
    window.settingsMenu = true
    window.menuSlot = slot
  }

  function openExtensionMenu(slot) {
    window.closeMenu()
    if (!window.dock.extensions.actionsFor(slot.extension).length) return
    window.menuExtension = slot.extension
    window.menuExtensionId = slot.extensionId
    window.menuSlot = slot
  }

  function checkExtensionMenu() {
    if (!window.menuExtensionId) return
    if (!window.dock || !window.extensionActions.length || window.dock.extensions.instanceFor(window.menuExtensionId) !== window.menuExtension)
      window.closeMenu()
  }

  function chooseExtensionAction(id) {
    var action = window.extensionActions.find(function(entry) { return entry.id === id })
    if (!action || action.enabled === false) return
    if (action.confirmation !== undefined) {
      var prompt = action.confirmation
      if (!prompt || ![prompt.title, prompt.message, prompt.acceptText].every(function(text) { return typeof text === "string" && text.length > 0 })) {
        window.dock.extensions.warn(window.menuExtensionId, "invalid confirmation for action " + id)
        return
      }
      window.confirmation = { id: id, title: prompt.title, message: prompt.message, acceptText: prompt.acceptText }
    } else {
      window.runExtensionAction(id)
    }
  }

  function runExtensionAction(id) {
    var extensionId = window.menuExtensionId
    var action = window.extensionActions.find(function(entry) { return entry.id === id })
    var prompt = action ? action.confirmation : undefined
    var accepted = window.confirmation
    var allowed = action && action.enabled !== false && window.dock && window.dock.extensions.instanceFor(extensionId) === window.menuExtension
      && (accepted ? accepted.id === id && prompt && accepted.title === prompt.title
        && accepted.message === prompt.message && accepted.acceptText === prompt.acceptText : prompt === undefined)
    window.closeMenu()
    if (allowed) window.dock.extensions.invoke(extensionId, "triggerAction", [id])
  }

  function settleShifts() {
    window.animateShifts = false
    Qt.callLater(function() { window.animateShifts = true })
  }

  function endDrag() {
    window.settleShifts()
    window.dragIndex = -1
    window.dropIndex = -1
    window.dragOffset = 0
  }

  function closeMenu() {
    window.menuItem = null
    window.settingsMenu = false
    window.menuExtensionId = ""
    window.menuExtension = null
    window.confirmation = null
    window.menuSlot = null
    if (window.autohide) hideTimer.restart()
  }

  // Places the menu inward of the dock, centered on a slot.
  function popupX(slot, popup) {
    if (!slot) return 0
    var center = slot.mapToItem(window.contentItem, slot.width / 2, 0).x
    if (window.position === "left") return body.x + body.width + window.gap
    if (window.position === "right") return body.x - window.gap - popup.width
    return Math.max(window.gap, Math.min(window.width - popup.width - window.gap, center - popup.width / 2))
  }

  function popupY(slot, popup) {
    if (!slot) return 0
    var center = slot.mapToItem(window.contentItem, 0, slot.height / 2).y
    if (window.position === "top") return body.y + body.height + window.gap
    if (window.position === "bottom") return body.y - window.gap - popup.height
    return Math.max(window.gap, Math.min(window.height - popup.height - window.gap, center - popup.height / 2))
  }

  visible: !remapGuard.remapping
  color: "transparent"
  WlrLayershell.namespace: "omarchy-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  // Reserve just the plate and its inset. Menus extend into the workspace.
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: window.shown && !window.autohide ? window.edgeInset + window.dockDepth : 0

  anchors {
    top: window.position !== "bottom"
    bottom: window.position !== "top"
    left: window.position !== "right"
    right: window.position !== "left"
  }

  implicitWidth: window.vertical ? window.edgeInset + window.dockDepth + window.popupRoom : 0
  implicitHeight: window.vertical ? 0 : window.edgeInset + window.dockDepth + window.popupRoom

  mask: Region {
    item: window.contentShown ? body : null

    Region { item: window.shown && window.autohide ? edgeTrigger : null }
    Region { item: menu.visible ? menu : null }
  }

  onAutohideChanged: window.revealed = false
  onSettingsOpenChanged: {
    if (!window.settingsOpen && window.autohide) {
      if (bodyHover.hovered || edgeHover.hovered) window.revealed = true
      hideTimer.restart()
    }
  }

  DockFileDrop {
    id: fileDrop

    anchors.fill: parent
    enabled: window.shown && !window.menuOpen && !window.dragging && window.insertIndex < 0
    appIds: window.dock ? window.dock.shownKeys() : []
    slotAt: window.fileDropSlotAt
    onFilesDropped: function(slot, uris) {
      if (slot.dropExtensionId) window.dock.extensions.invoke(slot.dropExtensionId, "dropFiles", [uris])
      else window.dock.openFiles(slot.appId, uris)
    }
    onActiveChanged: {
      if (active) window.revealed = true
      else if (window.autohide) hideTimer.restart()
    }
  }

  Timer {
    id: hideTimer
    // Long enough to cross a gap between the edge and the icons, no longer.
    interval: 150
    onTriggered: {
      if (!bodyHover.hovered && !edgeHover.hovered && !window.menuOpen && !window.settingsOpen && !window.dragging && !fileDrop.active) window.revealed = false
    }
  }

  // The strip along the screen edge that brings an auto-hidden dock back.
  Item {
    id: edgeTrigger

    // A file drag needs a continuous input region across the gap and the
    // moving plate until it reaches an app slot.
    readonly property int depth: window.edgeInset + (fileDrop.active ? window.dockDepth : Math.max(1, Style.spacing.xxs))

    x: window.position === "left" ? 0 : window.position === "right" ? window.width - depth : body.x
    y: window.position === "top" ? 0 : window.position === "bottom" ? window.height - depth : body.y
    width: window.vertical ? depth : body.width
    height: window.vertical ? body.height : depth

    HoverHandler {
      id: edgeHover
      onHoveredChanged: {
        if (hovered) window.revealed = true
        else hideTimer.restart()
      }
    }
  }

  ScreenMoveRemap {
    id: remapGuard
    window: window
  }

  HyprlandFocusGrab {
    active: window.menuOpen && !window.confirmation
    windows: [window]
    onCleared: if (!window.confirmation) window.closeMenu()
  }

  PanelWindow {
    screen: window.screen
    visible: window.shown && !!window.confirmation
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dogedock-confirmation"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors { top: true; bottom: true; left: true; right: true }

    FocusScope {
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) { event.accepted = confirmDialog.handleKey(event) }

      ConfirmDialog {
        id: confirmDialog

        anchors.fill: parent
        opened: !!window.confirmation
        selectedIndex: 0
        message: opened ? window.confirmation.title + "\n\n" + window.confirmation.message : ""
        confirmText: opened ? window.confirmation.acceptText : ""
        background: Util.alpha(Commons.Color.popups.background, 1)
        foreground: Commons.Color.popups.text
        onOpenedChanged: if (opened) selectedIndex = 0
        onCanceled: window.closeMenu()
        onConfirmed: if (window.confirmation) window.runExtensionAction(window.confirmation.id)
      }
    }
  }

  Item {
    id: body

    // The strip keeps its order in every language, like the bar: drags and
    // drops reckon slots along x from the first app. Only the menu mirrors.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    width: slots.implicitWidth + window.platePadding * 2
    height: slots.implicitHeight + window.platePadding * 2
    // How far the dock is tucked past its edge when auto-hide is active.
    property real tuck: window.tucked ? window.dockDepth + window.edgeInset : 0

    // Tucking away is quicker than coming back. A gentler curve than
    // Style.easeOut, which crosses the short slide in a frame or two.
    Behavior on tuck {
      id: tuckMotion
      enabled: window.shown
      NumberAnimation {
        duration: Style.duration(tuckMotion.targetValue > 0 ? 120 : 180)
        easing.type: Easing.OutCubic
      }
    }

    x: window.position === "left" ? window.edgeInset - tuck
      : window.position === "right" ? window.width - width - window.edgeInset + tuck
      : Math.round((window.width - width) / 2)
    y: window.position === "top" ? window.edgeInset - tuck
      : window.position === "bottom" ? window.height - height - window.edgeInset + tuck
      : Math.round((window.height - height) / 2)
    // Hide for fullscreen windows while keeping the icon textures ready.
    opacity: window.shown ? 1 : 0

    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Commons.Color.background, 0.72)
      border.color: Util.alpha(Commons.Color.foreground, 0.14)
      border.width: Math.min(1, Style.normalBorderWidth)
      radius: Math.min(window.dockDepth / 2, window.scaled(Math.max(Style.cornerRadius, Style.space(14))))
      antialiasing: true
    }

    HoverHandler {
      id: bodyHover
      onHoveredChanged: if (!hovered && window.autohide) hideTimer.restart()
    }

    Grid {
      id: slots
      anchors.centerIn: parent
      columns: window.vertical ? 1 : appRepeater.count + extensionRepeater.count + (window.dividerSpace > 0 ? 2 : 1)

      AppsSlot {}

      Repeater {
        id: appRepeater
        model: window.dock ? window.dock.itemModel : null

        delegate: AppSlot {}
      }

      Item {
        id: divider

        visible: window.dividerSpace > 0
        width: window.vertical ? window.slotSize : window.dividerSpace
        height: window.vertical ? window.dividerSpace : window.slotSize
        property real shift: window.insertIndex >= 0 ? window.slotSize / 2 : 0

        Behavior on shift {
          enabled: window.animateShifts
          NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
        }

        transform: Translate {
          x: window.vertical ? 0 : divider.shift
          y: window.vertical ? divider.shift : 0
        }

        Rectangle {
          anchors.centerIn: parent
          width: window.vertical ? window.iconSize : 1
          height: window.vertical ? 1 : window.iconSize
          color: Util.alpha(Commons.Color.foreground, 0.24)
        }
      }

      Repeater {
        id: extensionRepeater
        model: window.dock ? window.dock.extensions.model : null

        delegate: ExtensionSlot {}
      }
    }
  }

  component Slot: Item {
    id: slot

    property bool pressed: mouse.pressed
    property alias mouse: mouse

    width: window.slotSize
    height: window.slotSize

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.ArrowCursor
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    }
  }

  component AppsSlot: Slot {
    id: appsSlot

    property real displayedShift: window.insertIndex >= 0 ? -window.slotSize / 2 : 0

    Behavior on displayedShift {
      enabled: window.animateShifts
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }

    transform: Translate {
      x: window.vertical ? 0 : appsSlot.displayedShift
      y: window.vertical ? appsSlot.displayedShift : 0
    }

    mouse.onClicked: function(event) {
      if (event.button === Qt.RightButton) {
        window.openSettingsMenu(appsSlot)
        return
      }
      window.closeMenu()
      if (window.dock) window.dock.openApps()
    }

    // A grid of app squares reads as "all apps" in any icon theme. Drawn
    // rather than taken from a font, so its edges stay crisp at every scale.
    Item {
      x: window.iconInset
      y: window.iconInset
      width: window.iconSize
      height: window.iconSize

      Grid {
        readonly property int square: Math.round(window.iconSize * 0.16)

        anchors.centerIn: parent
        columns: 3
        spacing: Math.max(1, Math.round(window.iconSize * 0.07))

        Repeater {
          model: 9

          delegate: Rectangle {
            width: parent.square
            height: parent.square
            radius: Math.max(1, Math.round(parent.square * 0.2))
            color: Commons.Color.bar.text
          }
        }
      }
    }
  }

  component AppSlot: IconSlot {
    id: appSlot

    required property int index
    required property string key
    readonly property var modelData: window.dock ? window.dock.itemFor(key) : null
    property point pressPoint
    property bool dragged: false

    appId: key
    lifted: window.dragIndex === index
    displayName: window.dock ? window.dock.nameFor(modelData) : ""
    iconSource: window.dock && modelData ? window.dock.iconFor(modelData) : ""
    running: !!modelData && modelData.windows.length > 0

    // Slots between where the dragged app was and where it would land step
    // aside to make room; the dragged one follows the pointer.
    readonly property real shift: window.insertIndex >= 0 ? (index >= window.insertIndex ? 1 : -1) * window.slotSize / 2
      : !window.dragging ? 0
      : lifted ? window.dragOffset
      : (window.dragIndex < index && index <= window.dropIndex) ? -window.slotSize
      : (window.dropIndex <= index && index < window.dragIndex) ? window.slotSize
      : 0
    displayedShift: shift

    // Only while dragging: once the drop reorders the slots, they are already
    // where they were shown.
    Behavior on displayedShift {
      enabled: window.animateShifts && ((window.dragging && !appSlot.lifted) || window.insertIndex >= 0)
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }

    z: lifted ? 1 : 0

    // The slot, and the pointer handling in it, stays where it is; only the
    // icon moves. Reading the pointer through a slot that moves with it would
    // feed each move back into the next.
    function bodyPoint(event) {
      return appSlot.mapToItem(body, event.x, event.y)
    }

    mouse.onPressed: function(event) {
      appSlot.dragged = false
      if (event.button === Qt.LeftButton) appSlot.pressPoint = appSlot.bodyPoint(event)
    }

    mouse.onPositionChanged: function(event) {
      if (!(appSlot.mouse.pressedButtons & Qt.LeftButton)) return
      var point = appSlot.bodyPoint(event)
      var delta = window.vertical ? point.y - appSlot.pressPoint.y : point.x - appSlot.pressPoint.x
      // A press that wanders is a drag in the making, not a click.
      if (Math.hypot(point.x - appSlot.pressPoint.x, point.y - appSlot.pressPoint.y) > Style.space(4)) appSlot.dragged = true
      if (!window.dragging) {
        if (Math.abs(delta) < Style.space(6)) return
        window.closeMenu()
        // The landing slot first: with the dragged slot set and no landing
        // slot yet, every slot before it would count as in between and step
        // aside for a moment.
        window.dropIndex = appSlot.index
        window.dragIndex = appSlot.index
      }
      if (!appSlot.lifted) return
      window.dragOffset = delta
      window.dropIndex = DockModel.dropIndex(appSlot.index, delta, window.slotSize, appRepeater.count)
    }

    mouse.onReleased: {
      if (!appSlot.lifted) return
      var from = window.dragIndex
      var to = window.dropIndex
      appSlot.dragged = true
      window.endDrag()
      window.dock.moveItem(from, to)
    }

    mouse.onCanceled: if (appSlot.lifted) window.endDrag()

    mouse.onClicked: function(event) {
      // A drag ends in a release over the app, which is not a click on it.
      if (appSlot.dragged) {
        appSlot.dragged = false
        return
      }
      if (event.button === Qt.RightButton) {
        window.openMenu(appSlot.modelData, appSlot)
        return
      }
      window.closeMenu()
      if (event.button === Qt.MiddleButton) window.dock.launch(appSlot.modelData)
      else window.dock.activate(appSlot.modelData)
    }
  }

  component IconSlot: Slot {
    id: iconSlot

    property string displayName: ""
    property url iconSource
    property string appId: ""
    property string dropExtensionId: ""
    property bool lifted: false
    property bool running: false
    property real displayedShift: 0

    readonly property bool tooltipHovered: displayName.length > 0 && window.contentShown && mouse.containsMouse
      && !pressed && !window.dragging && window.insertIndex < 0 && !window.menuOpen && !fileDrop.active

    // The panel's input region excludes the tooltip so it never catches clicks.
    Loader {
      active: iconSlot.tooltipHovered

      readonly property real slotX: body.x + slots.x + iconSlot.x
      readonly property real slotY: body.y + slots.y + iconSlot.y
      readonly property int clearance: window.platePadding + window.gap

      x: window.position === "left" ? iconSlot.width + clearance
        : window.position === "right" ? -width - clearance
        : Math.round(Math.max(window.gap - slotX,
          Math.min((iconSlot.width - width) / 2, window.width - window.gap - width - slotX)))
      y: window.position === "bottom" ? -height - clearance
        : window.position === "top" ? iconSlot.height + clearance
        : Math.round(Math.max(window.gap - slotY,
          Math.min((iconSlot.height - height) / 2, window.height - window.gap - height - slotY)))

      sourceComponent: DockToolTip {
        text: iconSlot.displayName
        maximumWidth: Math.max(1, Math.min(Style.space(240),
          window.vertical ? window.popupRoom - window.gap : window.width - 2 * window.gap))
      }
    }

    Item {
      anchors.fill: parent
      transform: Translate {
        x: window.vertical ? 0 : iconSlot.displayedShift
        y: window.vertical ? iconSlot.displayedShift : 0
      }

      Rectangle {
        visible: fileDrop.highlightedSlot === iconSlot
        anchors.fill: parent
        anchors.margins: window.gap
        radius: Style.cornerRadius
        color: Util.alpha(Commons.Color.accent, 0.22)
        border.color: Commons.Color.accent
        border.width: Style.normalBorderWidth
      }

      DockAppIcon {
        id: appIcon

        x: window.iconInset
        y: window.iconInset
        width: window.iconSize
        height: window.iconSize
        source: iconSlot.iconSource
        scale: iconSlot.lifted ? 1.15 : 1
        transformOrigin: window.popOrigin

        Behavior on scale { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      }

      Rectangle {
        visible: iconSlot.running && !iconSlot.lifted
        width: window.indicatorSize
        height: width
        x: Math.round((parent.width - width) / 2)
        y: appIcon.y + appIcon.height + window.indicatorGap
        radius: width / 2
        color: Commons.Color.foreground
      }
    }
  }

  component ExtensionSlot: IconSlot {
    id: extensionSlot

    required property string extensionId
    readonly property var extension: window.dock ? window.dock.extensions.instanceFor(extensionId) : null

    displayName: extension && typeof extension.tooltip === "string" ? extension.tooltip : extensionId
    iconSource: {
      if (!extension) return ""
      var source = String(extension.iconSource || "")
      if (source.startsWith("file:///")) return source
      var name = extension.iconName || "application-x-executable"
      return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable", true)
    }
    dropExtensionId: extension && extension.acceptsFiles === true && typeof extension.dropFiles === "function" ? extensionId : ""
    displayedShift: window.insertIndex >= 0 ? window.slotSize / 2 : 0

    Behavior on displayedShift {
      enabled: window.animateShifts
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }

    mouse.acceptedButtons: Qt.LeftButton | Qt.RightButton
    mouse.onClicked: function(event) {
      if (event.button === Qt.RightButton) {
        window.openExtensionMenu(extensionSlot)
      } else {
        window.closeMenu()
        window.dock.extensions.invoke(extensionId, "activate", [])
      }
    }
  }

  BorderSurface {
    id: menu

    readonly property var item: window.menuItem
    readonly property bool hasEntry: !!item && !!window.dock && !!window.dock.entryFor(item)
    readonly property bool running: !!item && item.windows.length > 0

    visible: window.contentShown && window.menuOpen && !window.confirmation
    width: Math.min(Style.space(window.menuExtensionId ? 218 : 140) + padding * 2,
      (window.vertical ? window.popupRoom : window.width - window.gap) - window.gap)
    height: Math.min(menuColumn.implicitHeight + contentTopInset + contentBottomInset,
      (window.vertical ? window.height - window.gap : window.popupRoom) - window.gap)
    x: window.popupX(window.menuSlot, menu)
    y: window.popupY(window.menuSlot, menu)
    radius: Style.cornerRadius
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
    padding: Style.spacing.sm

    Flickable {
      id: menuViewport

      x: menu.contentLeftInset
      y: menu.contentTopInset
      width: menu.width - menu.contentLeftInset - menu.contentRightInset
      height: menu.height - menu.contentTopInset - menu.contentBottomInset
      contentWidth: width
      contentHeight: menuColumn.implicitHeight
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      clip: true

      Column {
        id: menuColumn

        width: menuViewport.width

        Repeater {
          model: [["top", Commons.I18n.t("dock.positionTop")], ["bottom", Commons.I18n.t("dock.positionBottom")], ["left", Commons.I18n.t("dock.positionLeft")], ["right", Commons.I18n.t("dock.positionRight")]]

          delegate: MenuRow {
            required property var modelData

            visible: window.settingsMenu
            text: modelData[1]
            checked: window.position === modelData[0]
            onTriggered: window.dock.setPosition(modelData[0])
          }
        }

        MenuRow {
          visible: window.settingsMenu
          text: Commons.I18n.t("dock.autoHide")
          checked: window.autohide
          onTriggered: window.dock.setAutohide(!window.autohide)
        }

        MenuRow {
          visible: window.settingsMenu && !!window.dock
          text: window.dock ? window.dock.settingsPanel.label : ""
          onTriggered: window.dock.settingsPanel.open(window.screen)
        }

        MenuRow {
          visible: menu.hasEntry && menu.running
          text: Commons.I18n.t("dock.newWindow")
          onTriggered: window.dock.launch(menu.item)
        }

        MenuRow {
          visible: menu.hasEntry
          text: menu.item && menu.item.pinned ? Commons.I18n.t("dock.removeFromDock") : Commons.I18n.t("dock.keepInDock")
          onTriggered: window.dock.setPinned(menu.item.key, !menu.item.pinned)
        }

        MenuRow {
          visible: menu.running
          text: Commons.I18n.t("dock.quit")
          onTriggered: window.dock.quit(menu.item)
        }

        Repeater {
          model: window.extensionActions

          delegate: MenuRow {
            required property var modelData

            text: modelData.text
            enabled: modelData.enabled !== false
            closeOnTrigger: false
            onTriggered: window.chooseExtensionAction(modelData.id)
          }
        }
      }
    }

    onVisibleChanged: if (visible) menuViewport.contentY = 0
  }

  component MenuRow: Rectangle {
    id: row

    property string text: ""
    property bool checked: false
    property bool closeOnTrigger: true
    signal triggered()

    width: parent ? parent.width : 0
    height: visible ? Style.spacing.popupRowHeight : 0
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Style.hoverFill : "transparent"

    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.controlPaddingX
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.controlPaddingX + (row.checked ? Style.space(18) : 0)
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: row.text
      color: Commons.Color.popups.text
      opacity: row.enabled ? 1 : 0.5
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    Text {
      visible: row.checked
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.controlPaddingX
      textFormat: Text.PlainText
      text: "✓"
      color: Commons.Color.accent
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        row.triggered()
        if (row.closeOnTrigger) window.closeMenu()
      }
    }
  }
}
