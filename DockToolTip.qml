import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BorderSurface {
  id: tooltip

  required property string text
  required property real maximumWidth

  implicitWidth: Math.min(maximumWidth, label.implicitWidth + contentLeftInset + contentRightInset)
  implicitHeight: label.implicitHeight + contentTopInset + contentBottomInset
  color: Commons.Color.tooltip.background
  borderSpec: Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, Style.normalBorderWidth)
  radius: Style.cornerRadius
  leftPadding: Style.spacing.controlPaddingX
  rightPadding: Style.spacing.controlPaddingX
  topPadding: Style.spacing.controlPaddingY
  bottomPadding: Style.spacing.controlPaddingY

  Text {
    id: label

    x: tooltip.contentLeftInset
    y: tooltip.contentTopInset
    width: Math.max(0, tooltip.width - tooltip.contentLeftInset - tooltip.contentRightInset)
    text: tooltip.text
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Commons.Color.tooltip.text
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
}
