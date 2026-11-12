pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var configured
  property alias model: iconModel

  readonly property var builtIns: ["trash"]
  property var sources: []
  property var instances: Object.create(null)

  ListModel { id: iconModel }

  onConfiguredChanged: Qt.callLater(syncSources)
  Component.onCompleted: Qt.callLater(syncSources)

  function warn(reference, message) {
    console.warn("DogeDock extension " + JSON.stringify(reference) + ": " + message)
  }

  function instanceFor(id) {
    return root.instances[id] || null
  }

  function syncSources() {
    var previous = new Map(root.sources.map(function(source) { return [source.reference, source] }))
    var next = []
    var seen = new Set()
    var references = Array.isArray(root.configured) ? root.configured : []
    if (root.configured !== undefined && !Array.isArray(root.configured))
      warn("dock.extensions", "expected an array")
    for (var value of references) {
      if (typeof value !== "string" || !value) {
        warn(value, "expected a built-in ID or an absolute directory path")
        continue
      }
      var reference = value.startsWith("/") ? value.replace(/\/+$/, "") || "/" : value
      if (seen.has(reference)) continue
      seen.add(reference)

      var source = previous.get(reference)
      if (source) {
        previous.delete(reference)
      } else {
        var external = reference.startsWith("/")
        if (!external && root.builtIns.indexOf(reference) < 0) {
          warn(reference, "unknown built-in ID")
          continue
        }
        var directory = external ? reference.replace(/\/$/, "") + "/"
          : decodeURIComponent(String(Qt.resolvedUrl("extensions/" + reference + "/")).slice("file://".length))
        source = sourceReader.createObject(root, { reference: reference, directory: directory, external: external })
      }
      next.push(source)
    }
    root.sources = next
    for (var removed of previous.values()) removed.destroy()
    reconcile()
  }

  function readManifest(source, contents) {
    try {
      var manifest = JSON.parse(contents)
      if (!Util.isPlainObject(manifest) || typeof manifest.id !== "string"
        || !/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(manifest.id)) throw new Error("invalid manifest ID")
      if (source.external ? root.builtIns.indexOf(manifest.id) >= 0 : manifest.id !== source.reference)
        throw new Error("reserved or mismatched ID: " + manifest.id)
      if (manifest.apiVersion !== 1) throw new Error("unsupported apiVersion: " + manifest.apiVersion)
      var path = typeof manifest.entryPoint === "string" ? manifest.entryPoint.split("/") : []
      if (!/^[a-zA-Z][a-zA-Z0-9_]*\.qml$/.test(path[path.length - 1] || "")
        || path.some(function(part) { return !part || part === ".." }))
        throw new Error("entryPoint must be a relative path to a file named like Extension.qml")

      return {
        id: manifest.id,
        entryUrl: Util.fileUrl(source.directory + manifest.entryPoint)
      }
    } catch (error) {
      warn(source.reference, String(error))
      return null
    }
  }

  function reconcile() {
    // Resolve claims in settings order, even when manifest reads finish out of order.
    var claimed = new Set()
    var waiting = false
    var active = []
    for (var source of root.sources) {
      if (source.manifest === undefined) waiting = true
      if (!source.manifest) continue
      var id = source.manifest.id
      if (claimed.has(id)) {
        if (!source.duplicate) warn(source.reference, "duplicate ID: " + id)
        source.duplicate = true
        if (source.instance) {
          source.instance.destroy()
          source.instance = null
        }
        source.started = false
        continue
      }
      claimed.add(id)
      source.duplicate = false
      if (!waiting && !source.started) source.load()
      if (source.instance) active.push(source)
    }
    publish(active)
  }

  function publish(active) {
    var next = Object.create(null)
    var keys = active.map(function(source) {
      next[source.manifest.id] = source.instance
      return source.manifest.id
    })
    var previous = Object.keys(root.instances)
    if (previous.length !== keys.length || keys.some(function(id) { return next[id] !== root.instances[id] }))
      root.instances = next

    for (var i = 0; i < keys.length; i++) {
      if (i < iconModel.count && iconModel.get(i).extensionId === keys[i]) continue
      var found = -1
      for (var j = i + 1; j < iconModel.count; j++) {
        if (iconModel.get(j).extensionId === keys[i]) { found = j; break }
      }
      if (found >= 0) iconModel.move(found, i, 1)
      else iconModel.insert(i, { extensionId: keys[i] })
    }
    if (iconModel.count > keys.length) iconModel.remove(keys.length, iconModel.count - keys.length)
  }

  function actionsFor(extension) {
    if (!extension || typeof extension.triggerAction !== "function" || !Array.isArray(extension.menuActions)) return []
    var ids = new Set()
    return extension.menuActions.filter(function(action) {
      if (!action || typeof action.id !== "string" || !action.id || typeof action.text !== "string" || !action.text
        || ids.has(action.id)) return false
      ids.add(action.id)
      return true
    })
  }

  function invoke(id, method, args) {
    var extension = instanceFor(id)
    if (!extension || typeof extension[method] !== "function") return
    try {
      extension[method].apply(extension, args)
    } catch (error) {
      warn(id, method + " failed: " + error)
    }
  }

  Component {
    id: sourceReader

    FileView {
      id: source

      required property string reference
      required property string directory
      required property bool external
      property var manifest
      property var instance: null
      property bool duplicate: false
      property bool started: false

      path: directory + "manifest.json"
      printErrors: false
      onLoaded: {
        manifest = root.readManifest(source, text())
        Qt.callLater(root.reconcile)
      }
      onLoadFailed: function(error) {
        root.warn(reference, "could not read manifest.json (" + error + ")")
        manifest = null
        Qt.callLater(root.reconcile)
      }

      function load() {
        started = true
        var component = Qt.createComponent(manifest.entryUrl, Component.PreferSynchronous)
        if (!component || component.status !== Component.Ready) {
          root.warn(reference, component ? component.errorString() || "QML entry point is not ready" : "could not load QML entry point")
          return
        }
        var object = component.createObject(source)
        if (!object || object instanceof Item || (object.iconName === undefined && object.iconSource === undefined)) {
          root.warn(reference, component.errorString() || "entry point must create a nonvisual object with iconName or iconSource")
          if (object) object.destroy()
          return
        }
        instance = object
      }
    }
  }
}
