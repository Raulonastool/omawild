import QtQuick
import qs.Commons
import "../js/Sprites.js" as Sprites

// Two panes: the species list, and the selected entry.
Item {
  id: root

  property var creatures: []          // full species list, in number order
  property var save: null             // { species: { id: {seen, observed} } }
  property int selectedIndex: 0
  property color ink: "#ffffff"
  property color accent: "#ffffff"
  property color dim: "#888888"
  property color rowFill: "#22ffffff"
  property color themeAccent: "#8fb8f0"

  // Themedle is recorded in whatever palette the desktop is wearing.
  function paletteFor(c) {
    if (!c) return ({})
    if (!(c.flags && c.flags.themed)) return c.palette
    var p = {}
    for (var k in c.palette) p[k] = c.palette[k]
    p.a = String(root.themeAccent)
    p.b = String(Qt.darker(root.themeAccent, 1.7))
    p.c = String(Qt.lighter(root.themeAccent, 1.5))
    return p
  }

  readonly property var visibleList: {
    var out = []
    for (var i = 0; i < creatures.length; i++) {
      var c = creatures[i]
      var rec = root.record(c.id)
      var secret = c.flags && c.flags.secret
      // Secret species stay off the list until they have actually turned up.
      if (secret && rec.seen <= 0) continue
      out.push(c)
    }
    return out
  }
  readonly property var current: visibleList.length ? visibleList[Math.min(selectedIndex, visibleList.length-1)] : null

  function record(id) {
    var s = save && save.species ? save.species[id] : null
    return s ? s : { seen: 0, observed: 0 }
  }
  function known(c) { return root.record(c.id).seen > 0 }
  function done(c)  { return root.record(c.id).observed >= (c.observationsRequired || 3) }

  function move(delta) {
    if (!visibleList.length) return
    selectedIndex = Math.max(0, Math.min(visibleList.length - 1, selectedIndex + delta))
    list.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  Row {
    anchors.fill: parent
    spacing: Style.spacing.lg

    // ------------------------------------------------------------- the list
    Item {
      width: Math.round(parent.width * 0.46)
      height: parent.height

      ListView {
        id: list
        anchors.fill: parent
        model: root.visibleList
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1

        delegate: Rectangle {
          required property int index
          required property var modelData
          readonly property bool sel: index === root.selectedIndex
          readonly property bool seen: root.known(modelData)

          width: list.width
          height: Style.space(22)
          color: sel ? root.rowFill : "transparent"

          Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(6)
            spacing: Style.spacing.md

            Text {
              text: String(modelData.number).padStart(3, "0")
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Text {
              text: seen ? modelData.name : "????????"
              color: sel ? root.accent : root.ink
              opacity: seen ? 1 : 0.35
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          // observation pips
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            text: {
              var need = modelData.observationsRequired || 3
              var got = root.record(modelData.id).observed
              var s = ""
              for (var i = 0; i < need; i++) s += (i < got ? "●" : "○")
              return s
            }
            color: root.done(modelData) ? root.accent : root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    // ------------------------------------------------------------ the entry
    Item {
      width: parent.width - Math.round(parent.width * 0.46) - Style.spacing.lg
      height: parent.height

      Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: Style.spacing.sm

        PixelSprite {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.current && root.known(root.current)
          rows: root.current ? (Sprites.ARCHETYPES[root.current.archetype] || Sprites.ARCHETYPES.blob) : []
          palette: root.paletteFor(root.current)
          pixel: 5
        }
        // Unknown species show a flat silhouette instead of the real colours.
        PixelSprite {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.current && !root.known(root.current)
          rows: root.current ? (Sprites.ARCHETYPES[root.current.archetype] || Sprites.ARCHETYPES.blob) : []
          palette: ({ o:"#000000", a:"#2a2f36", b:"#2a2f36", c:"#2a2f36",
                      e:"#2a2f36", p:"#2a2f36", d:"#2a2f36", f:"#2a2f36" })
          pixel: 5
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.current ? (root.known(root.current) ? root.current.name.toUpperCase() : "????????") : ""
          color: root.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.letterSpacing: 1
        }

        Item { width: 1; height: Style.space(4) }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: {
            if (!root.current) return ""
            var rec = root.record(root.current.id)
            if (rec.seen <= 0) return "Not yet observed."
            var e = root.current.entries || []
            var idx = Math.min(rec.observed, e.length) - 1
            return idx >= 0 ? e[idx] : "Observed, but not yet studied."
          }
          color: root.ink; opacity: 0.85
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Item { width: 1; height: Style.space(6) }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.current && root.known(root.current)
          text: {
            if (!root.current) return ""
            var rec = root.record(root.current.id)
            return "seen " + rec.seen + "    observed " + rec.observed
                 + " / " + (root.current.observationsRequired || 3)
          }
          color: root.dim
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
