import QtQml

QtObject {
  required property var settings
  property var event: []
  readonly property var icons: settings.show ? settings.names.map(function(name) {
    return {
      id: name,
      iconName: "folder",
      tooltip: name,
      acceptsFiles: true,
      menuActions: [{ id: "open", text: "Open" }, {
        id: "discard",
        text: "Discard",
        confirmation: { title: "Discard?", message: "Discard this item?", acceptText: "Discard" }
      }]
    }
  }) : []

  function activate(iconId) { event = ["activate", iconId] }
  function triggerAction(iconId, actionId) { event = ["action", iconId, actionId] }
  function dropFiles(iconId, uris) { event = ["drop", iconId].concat(uris) }
}
