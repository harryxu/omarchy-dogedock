.pragma library

var measuredBounds = Object.create(null)

function alphaBounds(pixels, width, height) {
  var left = width, top = height, right = -1, bottom = -1
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      // Ignore faint shadows when measuring the artwork.
      if (pixels[(y * width + x) * 4 + 3] < 32) continue
      left = Math.min(left, x)
      top = Math.min(top, y)
      right = Math.max(right, x)
      bottom = Math.max(bottom, y)
    }
  }
  return right < left ? null : { x: left, y: top, width: right - left + 1, height: bottom - top + 1 }
}

function placement(bounds, sampleSize, iconSize) {
  if (!bounds) return null
  var scale = iconSize / Math.max(bounds.width, bounds.height)
  return {
    size: sampleSize * scale,
    x: iconSize / 2 - (bounds.x + bounds.width / 2) * scale,
    y: iconSize / 2 - (bounds.y + bounds.height / 2) * scale
  }
}
