import QtQuick

// Each Dock owns its visual instance; the extension's state is shared.
Item {
  id: host

  required property var icon
  readonly property Component iconComponent: icon && icon.iconComponent instanceof Component ? icon.iconComponent : null
  property Item view: null
  property bool ready: false

  objectName: "dockExtensionIcon"
  enabled: false
  clip: true

  onIconComponentChanged: if (ready) rebuild()
  Component.onCompleted: {
    ready = true
    rebuild()
  }

  function rebuild() {
    if (view) {
      view.destroy()
      view = null
    }
    if (!iconComponent) return
    var object = null
    try {
      var component = iconComponent
      var initialIcon = icon
      // Keep departing views valid until QML completes their deferred destruction.
      object = component.createObject(host, { icon: Qt.binding(function() {
        return host.icon && host.icon.iconComponent === component ? host.icon : initialIcon
      }) })
      if (!(object instanceof Item)) throw new Error("iconComponent must create an Item with an icon property")
      object.width = Qt.binding(function() { return host.width })
      object.height = Qt.binding(function() { return host.height })
      view = object
    } catch (error) {
      console.warn("DogeDock extension icon: " + error)
      if (object) object.destroy()
    }
  }
}
