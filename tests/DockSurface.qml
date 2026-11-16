import QtQuick

Item {
  id: surface

  property var screen
  property Item contentItem: surface
  property int exclusiveZone: 0

  width: 1280
  height: 800
}
