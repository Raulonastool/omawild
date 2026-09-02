import QtQuick
import qs.Commons
import "../js/Sprites.js" as Sprites

// The encounter card. Presentational: the root owns all progression state.
Item {
  id: root

  property var species: null
  property int observed: 0            // observations AFTER this encounter
  property string stage: "appeared"   // appeared | entry
  property string flavour: ""
  property color ink: "#ffffff"
  property color accent: "#ffffff"
  property color dim: "#888888"
  property int unit: 6

  readonly property int required: species ? (species.observationsRequired || 3) : 3
  readonly property bool complete: observed >= required

  function reveal(level) { return observed >= level }

  Column {
    anchors.centerIn: parent
    spacing: Style.spacing.lg
    width: parent.width

    // ---------------------------------------------------------- the creature
    Item {
      width: parent.width
      height: sprite.height + Style.space(8)

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: sprite.height - Style.space(2)
        width: sprite.width * 0.55
        height: Style.space(5)
        radius: height / 2
        color: "#000000"
        opacity: 0.22
      }

      PixelSprite {
        id: sprite
        anchors.horizontalCenter: parent.horizontalCenter
        rows: root.species ? (Sprites.ARCHETYPES[root.species.archetype] || Sprites.ARCHETYPES.blob) : []
        palette: root.species ? root.species.palette : ({})
        pixel: root.unit
        y: bob

        property real bob: 0
        // Small idle bob; Mprisprite keeps time, Segfaulter stutters.
        SequentialAnimation on bob {
          running: true; loops: Animation.Infinite
          NumberAnimation { to: -3; duration: 520; easing.type: Easing.InOutSine }
          NumberAnimation { to:  0; duration: 520; easing.type: Easing.InOutSine }
        }
        opacity: 1
        SequentialAnimation on opacity {
          running: root.species && root.species.flags && root.species.flags.flicker
          loops: Animation.Infinite
          NumberAnimation { to: 1;    duration: 900 }
          NumberAnimation { to: 0.25; duration: 60 }
          NumberAnimation { to: 1;    duration: 50 }
          NumberAnimation { to: 1;    duration: 700 }
          NumberAnimation { to: 0.4;  duration: 40 }
          NumberAnimation { to: 1;    duration: 40 }
        }
      }
    }

    // ------------------------------------------------------------ "appeared"
    Column {
      width: parent.width
      spacing: Style.spacing.md
      visible: root.stage === "appeared"

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.species ? ("A " + root.species.name.toUpperCase() + " appeared!") : ""
        color: root.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.letterSpacing: 1
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.flavour
        visible: root.flavour !== ""
        color: root.ink
        opacity: 0.5
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.italic: true
      }
    }

    // --------------------------------------------------------- the guide entry
    Column {
      width: parent.width
      spacing: Style.spacing.sm
      visible: root.stage === "entry"

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.species ? root.species.name.toUpperCase() : ""
        color: root.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.letterSpacing: 1
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.species ? ("#" + String(root.species.number).padStart(3, "0")) : ""
        color: root.ink; opacity: 0.4
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Item { width: 1; height: Style.space(6) }

      Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 2
        columnSpacing: Style.spacing.lg
        rowSpacing: Style.spacing.xs

        Text { text: "Classification"; color: root.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        Text {
          text: root.reveal(2) && root.species ? root.species.classification : "????"
          color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
        }
        Text { text: "Habitat"; color: root.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        Text {
          text: root.reveal(2) && root.species ? root.species.habitat : "????"
          color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
        }
        Text { text: "Rarity"; color: root.dim; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
        Text {
          text: root.reveal(2) && root.species ? root.species.rarity : "????"
          color: root.ink; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
        }
      }

      Item { width: 1; height: Style.space(6) }

      Text {
        width: parent.width * 0.86
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: {
          if (!root.species) return ""
          var e = root.species.entries || []
          var idx = Math.min(root.observed, e.length) - 1
          return idx >= 0 ? e[idx] : "????"
        }
        color: root.ink; opacity: 0.85
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Item { width: 1; height: Style.space(6) }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.complete ? "ENTRY COMPLETE"
                            : ("Observed " + root.observed + " / " + root.required)
        color: root.complete ? root.accent : root.ink
        opacity: root.complete ? 1 : 0.55
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: root.complete ? 1 : 0
      }
    }
  }
}
