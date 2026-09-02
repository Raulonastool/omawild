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

  // Local context, so a creature can react to the machine it lives on.
  property string phase: "day"
  property bool mediaPlaying: false
  property int batteryPercent: 100
  property color themeAccent: "#8fb8f0"
  property int variantSeed: 0

  readonly property var flags: (species && species.flags) ? species.flags : ({})

  // Difflet's two halves never quite agree, and the mismatch changes each time.
  readonly property var twoTone: ["#5fb86f", "#6fa8d0", "#d0a85f", "#b06fd0", "#d06f8a", "#6fd0c0"]

  property bool blinking: false
  property real hopX: 0
  property real hopY: 0
  Behavior on hopX { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }

  // Bashling's eyes tick like a terminal cursor: a long wait, a short close.
  Timer {
    id: blinkTimer
    running: root.flags.blink === true
    interval: 2400
    repeat: true
    onTriggered: {
      if (root.blinking) { root.blinking = false; interval = 1700 + Math.random() * 2400 }
      else { root.blinking = true; interval = 120 }
    }
  }

  // Cursoroo will not stay where you last saw it.
  Timer {
    running: root.flags.hops === true
    interval: 2000
    repeat: true
    onTriggered: {
      root.hopX = (Math.random() * 2 - 1) * (root.unit * 9)
      hopArc.restart()
      interval = 1500 + Math.random() * 2200
    }
  }
  SequentialAnimation {
    id: hopArc
    NumberAnimation { target: root; property: "hopY"; to: -10; duration: 120; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "hopY"; to: 0;   duration: 140; easing.type: Easing.InQuad }
  }

  // Cachemunk pockets another glowing block now and then.
  property real stuffScale: 0
  Timer {
    running: root.flags.stuffs === true
    interval: 2600
    repeat: true
    onTriggered: { stuffAnim.restart(); interval = 2200 + Math.random() * 2600 }
  }
  SequentialAnimation {
    id: stuffAnim
    NumberAnimation { target: root; property: "stuffScale"; to: 1; duration: 160; easing.type: Easing.OutBack }
    PauseAnimation { duration: 260 }
    NumberAnimation { target: root; property: "stuffScale"; to: 0; duration: 180; easing.type: Easing.InQuad }
  }

  // Voltkit slows down as the charge falls; Mprisprite speeds up to the music.
  readonly property int bobDuration: {
    if (root.flags.dancesToMedia && root.mediaPlaying) return 240
    if (root.flags.tiresWithBattery) {
      var b = Math.max(0, Math.min(100, root.batteryPercent))
      return Math.round(430 + (100 - b) * 6)
    }
    return 520
  }
  readonly property real bobAmount: {
    if (root.flags.dancesToMedia && root.mediaPlaying) return -7
    if (root.flags.tiresWithBattery) {
      var b = Math.max(0, Math.min(100, root.batteryPercent))
      return -(1.0 + (b / 100) * 3.0)
    }
    return -3
  }

  // Palette after personality: Themedle borrows the desktop theme, Difflet
  // remixes one of its tones, and a blink hides the eyes in the body colour.
  readonly property var livePalette: {
    if (!species) return ({})
    var p = {}
    for (var k in species.palette) p[k] = species.palette[k]
    if (root.flags.themed) {
      p.a = String(root.themeAccent)
      p.b = String(Qt.darker(root.themeAccent, 1.7))
      p.c = String(Qt.lighter(root.themeAccent, 1.5))
    }
    if (root.flags.varies) {
      p.c = root.twoTone[root.variantSeed % root.twoTone.length]
      p.b = root.twoTone[(root.variantSeed + 3) % root.twoTone.length]
    }
    if (root.blinking) { p.e = p.a; p.p = p.a }
    return p
  }

  readonly property int required: species ? (species.observationsRequired || 3) : 3
  readonly property bool complete: observed >= required

  // Rootling keeps its details back until it has been fully observed.
  function reveal(level) {
    if (root.flags.withholds) return root.observed >= root.required
    return root.observed >= level
  }

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
        anchors.horizontalCenterOffset: root.hopX
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
        anchors.horizontalCenterOffset: root.hopX
        rows: root.species ? (Sprites.ARCHETYPES[root.species.archetype] || Sprites.ARCHETYPES.blob) : []
        palette: root.livePalette
        pixel: root.unit
        // Bitbat hangs upside down once the light has gone.
        flipV: root.flags.invertsAtNight === true && root.phase === "night"
        y: bob + root.hopY

        property real bob: 0
        SequentialAnimation on bob {
          running: true; loops: Animation.Infinite
          NumberAnimation { to: root.bobAmount; duration: root.bobDuration; easing.type: Easing.InOutSine }
          NumberAnimation { to: 0;              duration: root.bobDuration; easing.type: Easing.InOutSine }
        }

        opacity: 1
        SequentialAnimation on opacity {
          running: root.flags.flicker === true
          loops: Animation.Infinite
          NumberAnimation { to: 1;    duration: 900 }
          NumberAnimation { to: 0.25; duration: 60 }
          NumberAnimation { to: 1;    duration: 50 }
          NumberAnimation { to: 1;    duration: 700 }
          NumberAnimation { to: 0.4;  duration: 40 }
          NumberAnimation { to: 1;    duration: 40 }
        }
      }

      // Cachemunk stuffing another glowing block into its cheeks.
      Rectangle {
        visible: root.flags.stuffs === true && root.stuffScale > 0.01
        width: root.unit * 2
        height: width
        radius: 1
        color: "#ffe08a"
        x: sprite.x + sprite.width - root.unit * 3
        y: sprite.y + root.unit * 4
        scale: root.stuffScale
        opacity: root.stuffScale
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
