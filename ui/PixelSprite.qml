import QtQuick

// Paints a character-grid sprite. "." and " " are transparent; any other
// character indexes `palette`, which may be an object (char -> colour) or an
// array (digit -> colour).
Canvas {
  id: root

  property var rows: []
  property var palette: ({})
  property int pixel: 4
  property real alpha: 1.0

  readonly property int cols: (rows && rows.length) ? String(rows[0]).length : 0
  readonly property int lines: rows ? rows.length : 0

  implicitWidth: cols * pixel
  implicitHeight: lines * pixel
  width: implicitWidth
  height: implicitHeight
  renderStrategy: Canvas.Cooperative

  onRowsChanged: requestPaint()
  onPaletteChanged: requestPaint()
  onPixelChanged: requestPaint()
  onAlphaChanged: requestPaint()

  function colourFor(ch) {
    if (Array.isArray(palette)) return palette[parseInt(ch, 10)]
    return palette[ch]
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.globalAlpha = root.alpha
    for (var y = 0; y < root.lines; y++) {
      var line = String(root.rows[y])
      for (var x = 0; x < line.length; x++) {
        var ch = line.charAt(x)
        if (ch === "." || ch === " ") continue
        var col = root.colourFor(ch)
        if (!col) continue
        ctx.fillStyle = col
        ctx.fillRect(x * root.pixel, y * root.pixel, root.pixel, root.pixel)
      }
    }
  }
}
