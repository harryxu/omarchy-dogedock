pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Commons
import "ExtensionSettingsModel.js" as Settings

Item {
  id: root

  property var configured
  property alias model: iconModel

  readonly property var builtIns: [
    { id: "trash", label: qsTr("Trash") },
    { id: "folders", label: qsTr("Folders") }
  ]
  readonly property var builtInIds: builtIns.map(function(extension) { return extension.id })
  readonly property var entries: readEntries(configured)
  readonly property var settingsSources: builtInIds.map(sourceFor).filter(function(source) { return !!source })
    .concat(sources.filter(function(source) { return source.external }))
  property var sources: []
  property var instances: Object.create(null)
  property var iconsByKey: new Map()

  ListModel { id: iconModel }

  onEntriesChanged: Qt.callLater(syncSources)
  Component.onCompleted: Qt.callLater(syncSources)

  function warn(reference, message) {
    console.warn("DogeDock extension " + JSON.stringify(reference) + ": " + message)
  }

  function instanceFor(id) {
    return root.instances[id] || null
  }

  function sourceFor(reference) {
    return root.sources.find(function(source) { return source.reference === reference }) || null
  }

  function iconFor(key) {
    var entry = root.iconsByKey.get(key)
    return entry ? entry.icon : null
  }

  function readEntries(configured) {
    var entries = new Map()
    if (!Array.isArray(configured)) {
      if (configured !== undefined) warn("dock.extensions", "expected an array")
      return []
    }
    for (var value of configured) {
      var enabled = true
      var settings
      if (Util.isPlainObject(value)) {
        var hasId = value.id !== undefined
        var hasPath = value.path !== undefined
        if (hasId === hasPath
          || (hasId && (typeof value.id !== "string" || !value.id || value.id.startsWith("/")))
          || (hasPath && (typeof value.path !== "string" || !value.path.startsWith("/")))
          || (value.enabled !== undefined && typeof value.enabled !== "boolean")) {
          warn(value, "expected a built-in id or absolute path and an optional boolean enabled")
          continue
        }
        enabled = value.enabled !== false
        settings = value.settings
        value = hasId ? value.id : value.path
      } else {
        settings = undefined
      }
      if (typeof value !== "string" || !value) {
        warn(value, "expected a built-in ID or an absolute directory path")
        continue
      }
      var reference = value.startsWith("/") ? value.replace(/\/+$/, "") || "/" : value
      var previous = entries.get(reference)
      if (previous && (previous.enabled || !enabled)) continue
      entries.delete(reference)
      entries.set(reference, { reference: reference, enabled: enabled, settings: settings })
    }
    return Array.from(entries.values())
  }

  function syncSources() {
    var previous = new Map(root.sources.map(function(source) { return [source.reference, source] }))
    var next = []
    var entries = root.entries.slice()
    for (var builtIn of root.builtIns) {
      if (!entries.some(function(entry) { return entry.reference === builtIn.id }))
        entries.push({ reference: builtIn.id, enabled: false })
    }
    for (var entry of entries) {
      var reference = entry.reference
      var source = previous.get(reference)
      if (source) {
        previous.delete(reference)
      } else {
        var external = reference.startsWith("/")
        var builtInInfo = root.builtIns.find(function(info) { return info.id === reference })
        if (!external && !builtInInfo) {
          if (entry.enabled) warn(reference, "unknown built-in ID")
          continue
        }
        var directory = external ? reference.replace(/\/$/, "") + "/"
          : decodeURIComponent(String(Qt.resolvedUrl("extensions/" + reference + "/")).slice("file://".length))
        source = sourceReader.createObject(root, {
          reference: reference, directory: directory, external: external,
          builtInLabel: builtInInfo ? builtInInfo.label : ""
        })
      }
      source.configuredEnabled = entry.enabled
      if (JSON.stringify(source.rawSettings) !== JSON.stringify(entry.settings))
        source.rawSettings = entry.settings
      next.push(source)
    }
    if (next.length !== root.sources.length || next.some(function(source, index) { return source !== root.sources[index] }))
      root.sources = next
    for (var removed of previous.values()) removed.destroy()
    reconcile()
  }

  function readManifest(source, contents) {
    var manifest = JSON.parse(contents)
    if (!Util.isPlainObject(manifest) || typeof manifest.id !== "string"
      || !/^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(manifest.id)) throw new Error("invalid manifest ID")
    if (source.external ? root.builtInIds.indexOf(manifest.id) >= 0 : manifest.id !== source.reference)
      throw new Error("reserved or mismatched ID: " + manifest.id)
    var path = typeof manifest.entryPoint === "string" ? manifest.entryPoint.split("/") : []
    if (!/^[a-zA-Z][a-zA-Z0-9_]*\.qml$/.test(path[path.length - 1] || "")
      || path.some(function(part) { return !part || part === ".." }))
      throw new Error("entryPoint must be a relative path to a file named like Extension.qml")

    return {
      id: manifest.id,
      name: typeof manifest.name === "string" && manifest.name.trim() ? manifest.name : manifest.id,
      hasSettings: manifest.settings !== undefined,
      fields: Settings.readFields(manifest.settings),
      entryUrl: Util.fileUrl(source.directory + manifest.entryPoint)
    }
  }

  function reconcile() {
    // Resolve claims in settings order, even when manifest reads finish out of order.
    var claimed = new Set()
    var waiting = false
    var active = []
    for (var source of root.sources) {
      if (!source.configuredEnabled) {
        source.stop()
        continue
      }
      if (source.manifest === undefined) waiting = true
      if (!source.manifest) continue
      var id = source.manifest.id
      if (claimed.has(id)) {
        if (!source.duplicate) warn(source.reference, "duplicate ID: " + id)
        source.stop()
        source.duplicate = true
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
    var icons = new Map()
    var rows = []
    for (var source of active) {
      var id = source.manifest.id
      next[id] = source.instance
      var published = source.usesIconList ? source.extensionIcons : [source.instance]
      if (!Array.isArray(published)) continue
      for (var icon of published) {
        var iconId = source.usesIconList ? icon && icon.id : ""
        if (source.usesIconList && (typeof iconId !== "string" || !iconId || (!icon.iconName && !icon.iconSource))) continue
        var key = JSON.stringify([id, iconId])
        if (icons.has(key)) continue
        icons.set(key, { icon: icon, iconId: iconId, extensionId: id })
        rows.push({ extensionId: id, iconKey: key })
      }
    }
    var previous = Object.keys(root.instances)
    var ids = Object.keys(next)
    if (previous.length !== ids.length || ids.some(function(id) { return next[id] !== root.instances[id] }))
      root.instances = next
    root.iconsByKey = icons

    for (var i = 0; i < rows.length; i++) {
      if (i < iconModel.count && iconModel.get(i).iconKey === rows[i].iconKey) continue
      var found = -1
      for (var j = i + 1; j < iconModel.count; j++) {
        if (iconModel.get(j).iconKey === rows[i].iconKey) { found = j; break }
      }
      if (found >= 0) iconModel.move(found, i, 1)
      else iconModel.insert(i, rows[i])
    }
    if (iconModel.count > rows.length) iconModel.remove(rows.length, iconModel.count - rows.length)
  }

  function actionsFor(extension, icon) {
    if (!extension || !icon || typeof extension.triggerAction !== "function" || !Array.isArray(icon.menuActions)) return []
    var ids = new Set()
    return icon.menuActions.filter(function(action) {
      if (!action || typeof action.id !== "string" || !action.id || typeof action.text !== "string" || !action.text
        || ids.has(action.id)) return false
      ids.add(action.id)
      return true
    })
  }

  function invokeIcon(key, method, args) {
    var entry = root.iconsByKey.get(key)
    if (!entry || (method === "dropFiles" && entry.icon.acceptsFiles !== true)) return
    var extension = instanceFor(entry.extensionId)
    if (!extension || typeof extension[method] !== "function") return
    try {
      extension[method].apply(extension, entry.iconId ? [entry.iconId].concat(args) : args)
    } catch (error) {
      warn(entry.extensionId, method + " failed: " + error)
    }
  }

  Component {
    id: sourceReader

    FileView {
      id: source

      required property string reference
      required property string directory
      required property bool external
      required property string builtInLabel
      property bool configuredEnabled: false
      property var rawSettings
      property var manifest
      property var instance: null
      property bool duplicate: false
      property bool started: false
      property string manifestError: ""
      property string loadError: ""
      readonly property string label: builtInLabel || (manifest ? manifest.name : reference)
      readonly property string error: manifestError || loadError || (duplicate ? qsTr("Another configured extension uses this ID.") : "")
      readonly property var fields: manifest ? manifest.fields : []
      readonly property var resolved: Settings.resolve(fields, rawSettings)
      readonly property bool usesIconList: instance !== null && ("icons" in instance)
      readonly property var extensionIcons: usesIconList ? instance.icons : null

      onExtensionIconsChanged: Qt.callLater(root.reconcile)

      path: directory + "manifest.json"
      printErrors: false
      onLoaded: {
        try {
          manifest = root.readManifest(source, text())
          manifestError = ""
        } catch (error) {
          manifestError = String(error)
          root.warn(reference, manifestError)
          manifest = null
        }
        Qt.callLater(root.reconcile)
      }
      onLoadFailed: function(error) {
        manifestError = qsTr("Could not read manifest.json (%1).").arg(error)
        root.warn(reference, manifestError)
        manifest = null
        Qt.callLater(root.reconcile)
      }

      function stop() {
        if (instance) {
          instance.destroy()
          instance = null
        }
        duplicate = false
        started = false
        loadError = ""
      }

      function load() {
        started = true
        var component = Qt.createComponent(manifest.entryUrl, Component.PreferSynchronous)
        if (!component || component.status !== Component.Ready) {
          loadError = component ? component.errorString() || qsTr("QML entry point is not ready.") : qsTr("Could not load QML entry point.")
          root.warn(reference, loadError)
          return
        }
        var properties = manifest.hasSettings ? { settings: Qt.binding(function() { return source.resolved.values }) } : {}
        var object = component.createObject(source, properties)
        if (!object || object instanceof Item)
          loadError = component.errorString() || qsTr("The QML entry point must create a nonvisual object.")
        else if (manifest.hasSettings && !("settings" in object))
          loadError = qsTr("The QML entry point must provide a settings property when the manifest declares settings.")
        else if ("icons" in object) {
          if (!Array.isArray(object.icons)) loadError = qsTr("The icons property must contain an array.")
        } else if (object.iconName === undefined && object.iconSource === undefined)
          loadError = qsTr("The QML entry point must provide an icons array.")

        if (loadError) {
          root.warn(reference, loadError)
          if (object) object.destroy()
          return
        }
        instance = object
      }
    }
  }
}
