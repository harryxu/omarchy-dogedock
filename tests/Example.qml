import QtQml

QtObject {
  id: extension

  property int activations: 0
  readonly property string iconName: "dialog-information"
  readonly property string tooltip: Qt.resolvedUrl(".").toString()
  readonly property var menuActions: [
    { id: "reset", text: "Reset" },
    { id: "reset", text: "Duplicate" },
    { id: "invalid" }
  ]

  function activate() { extension.activations++ }
  function triggerAction(id) { if (id === "reset") extension.activations = 0 }
}
