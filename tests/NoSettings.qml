import QtQml

QtObject {
  property string activated: ""
  readonly property var icons: [
    { id: "first", iconName: "folder" },
    { id: "second", iconName: "document-open" }
  ]

  function activate(iconId) { activated = iconId }
}
