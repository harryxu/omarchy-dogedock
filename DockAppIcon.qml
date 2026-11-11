pragma ComponentBehavior: Bound

import QtQuick
import "IconGeometry.js" as Geometry

Item {
  id: root

  required property url source

  readonly property int sampleSize: 144
  property var bounds
  readonly property var placement: Geometry.placement(bounds, sampleSize, width)

  onSourceChanged: bounds = Geometry.measuredBounds[String(source)]

  Image {
    id: artwork

    x: root.placement ? root.placement.x : 0
    y: root.placement ? root.placement.y : 0
    width: root.placement ? root.placement.size : root.width
    height: width
    source: root.source
    sourceSize: Qt.size(root.sampleSize, root.sampleSize)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    mipmap: true
  }

  Loader {
    id: samplerLoader

    // The grab needs a mapped window. Release the sampler once the bounds are cached.
    active: root.bounds === undefined && artwork.status === Image.Ready && root.width > 0
      && root.visible && !!root.Window.window && root.Window.window.visible

    sourceComponent: Canvas {
      id: sampler

      readonly property string sourceKey: String(root.source)
      property var request: null

      // Match the grab's pixel grid to the Canvas item even on HiDPI outputs.
      width: root.sampleSize
      height: root.sampleSize
      canvasSize: Qt.size(width, height)
      opacity: 0
      renderTarget: Canvas.Image
      contextType: "2d"

      onAvailableChanged: if (available) Qt.callLater(measure)
      onImageLoaded: requestPaint()
      onSourceKeyChanged: {
        if (request && request.result) unloadImage(request.result.url)
        request = null
        Qt.callLater(measure)
      }

      function measure() {
        if (!available || request || !samplerLoader.active) return
        var key = sourceKey
        if (Geometry.measuredBounds[key] !== undefined) {
          root.bounds = Geometry.measuredBounds[key]
          return
        }

        // Grab the unscaled artwork through Qt so file and theme-provider icons
        // are measured the same way. The request identifies this grab on source changes.
        var pending = { result: null }
        request = pending
        if (!artwork.grabToImage(function(result) {
          if (!sampler || sampler.request !== pending) return
          pending.result = result
          sampler.loadImage(result.url)
          sampler.requestPaint()
        }, Qt.size(width, height))) request = null
      }

      onPaint: {
        if (!request || !request.result || !isImageLoaded(request.result.url)) return
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.drawImage(request.result.url, 0, 0, width, height)
        var bounds = Geometry.alphaBounds(ctx.getImageData(0, 0, width, height).data, width, height)
        unloadImage(request.result.url)
        request = null
        Geometry.measuredBounds[sourceKey] = bounds
        root.bounds = bounds
      }
    }
  }
}
