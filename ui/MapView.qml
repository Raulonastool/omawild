import QtQuick
import "../js/TileArt.js" as TileArt

// The whole meadow in one canvas. Terrain is static for a given palette, so
// this only repaints when the map or the time-of-day palette changes.
Canvas {
  id: root

  property var mapData: null
  property var palette: ({})
  property int tile: 32

  readonly property int cols: mapData ? mapData.width : 0
  readonly property int lines: mapData ? mapData.height : 0

  implicitWidth: cols * tile
  implicitHeight: lines * tile
  width: implicitWidth
  height: implicitHeight
  renderStrategy: Canvas.Cooperative

  onMapDataChanged: requestPaint()
  onPaletteChanged: requestPaint()
  onTileChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    if (!mapData || !mapData.rows) return

    var unit = root.tile / 8          // one pattern pixel
    var legend = mapData.legend || {}

    for (var y = 0; y < root.lines; y++) {
      var line = String(mapData.rows[y])
      for (var x = 0; x < root.cols; x++) {
        var terrain = legend[line.charAt(x)] || "ground"
        var ramp = root.palette[terrain]
        if (!ramp) continue

        // Everything that is not ground sits on a ground bed, so trees and
        // rocks do not punch transparent holes in the meadow.
        var bed = root.palette.ground
        if (bed) { ctx.fillStyle = bed[0]; ctx.fillRect(x*root.tile, y*root.tile, root.tile, root.tile) }

        var pattern = TileArt.TILES[terrain]
        if (!pattern) continue
        for (var py = 0; py < 8; py++) {
          var prow = pattern[py]
          for (var px = 0; px < 8; px++) {
            var col = ramp[parseInt(prow.charAt(px), 10)]
            if (!col) continue
            ctx.fillStyle = col
            ctx.fillRect(x*root.tile + px*unit, y*root.tile + py*unit, unit, unit)
          }
        }
      }
    }
  }
}
