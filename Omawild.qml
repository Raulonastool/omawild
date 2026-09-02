import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "js/TileArt.js" as TileArt
import "js/Sprites.js" as Sprites
import "js/Encounters.js" as Encounters
import "ui" as Ui

// Omawild - a tiny creature-discovery game. Root overlay and screen router.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: (manifest && manifest.id) || "raulonastool.omawild"

  property bool opened: false
  property string screen: "map"          // map | encounter | guide

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omawild"
  readonly property string savePath: stateDir + "/save.json"

  // ------------------------------------------------------------------- world
  property var mapData: null
  property var creatures: []
  property int px: 4
  property int py: 6
  property int steps: 0
  property bool hasMoved: false
  property bool sawFirstEncounter: false

  property int hour: 12
  readonly property string phase: TileArt.phaseFor(hour)
  property var palette: TileArt.paletteFor("day")
  onPhaseChanged: root.palette = TileArt.paletteFor(root.phase)

  Ui.Context { id: ctx }
  Ui.Sfx { id: sfx; muted: root.muted }

  property bool muted: false

  Timer {
    interval: 60000; running: root.opened; repeat: true
    onTriggered: { var h = new Date().getHours(); if (h !== root.hour) root.hour = h; ctx.refresh() }
  }

  // -------------------------------------------------------------------- save
  property var save: ({ version: 1, firstPlayed: "", steps: 0, encounters: 0, species: ({}) })
  property bool saveDirty: false

  function record(id) {
    var s = save.species ? save.species[id] : null
    return s ? s : { seen: 0, observed: 0, firstSeen: "" }
  }
  function totalSpecies() { return creatures.length }
  function discoveredCount() {
    var n = 0
    for (var i = 0; i < creatures.length; i++) if (record(creatures[i].id).seen > 0) n++
    return n
  }
  function completedCount() {
    var n = 0
    for (var i = 0; i < creatures.length; i++) {
      var c = creatures[i]
      if (record(c.id).observed >= (c.observationsRequired || 3)) n++
    }
    return n
  }

  function touchSave(mutate) {
    var next = JSON.parse(JSON.stringify(root.save))
    if (!next.species) next.species = {}
    if (!next.firstPlayed) next.firstPlayed = new Date().toISOString()
    mutate(next)
    next.steps = root.steps
    root.save = next
    root.saveDirty = true
    saveTimer.restart()
  }

  Timer {
    id: saveTimer
    interval: 1200
    onTriggered: {
      if (!root.saveDirty) return
      saveFile.setText(JSON.stringify(root.save, null, 2) + "\n")
      root.saveDirty = false
    }
  }

  Process { id: mkdirProc; command: ["mkdir", "-p", root.stateDir]; running: true }

  FileView {
    id: saveFile
    path: root.savePath
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var s = JSON.parse(text())
        if (s && s.version === 1) {
          if (!s.species) s.species = {}
          root.save = s
          root.steps = s.steps || 0
          root.hasMoved = root.steps > 0
          root.sawFirstEncounter = (s.encounters || 0) > 0
          root.muted = s.muted === true
        }
      } catch (e) { console.warn("omawild: save parse failed", e) }
    }
  }

  FileView {
    path: Qt.resolvedUrl("data/map.json").toString().replace("file://", "")
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var m = JSON.parse(text())
        root.mapData = m
        if (m.spawn && root.steps === 0) { root.px = m.spawn.x; root.py = m.spawn.y }
      } catch (e) { console.warn("omawild: map parse failed", e) }
    }
    onFileChanged: reload()
  }

  FileView {
    path: Qt.resolvedUrl("data/creatures.json").toString().replace("file://", "")
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        var list = (d && d.species) ? d.species.slice() : []
        list.sort(function(a, b) { return a.number - b.number })
        root.creatures = list
      } catch (e) { console.warn("omawild: creatures parse failed", e) }
    }
    onFileChanged: reload()
  }

  // --------------------------------------------------------------- map rules
  function terrainAt(x, y) {
    if (!mapData || !mapData.rows) return "ground"
    if (x < 0 || y < 0 || x >= mapData.width || y >= mapData.height) return "tree"
    return (mapData.legend || {})[String(mapData.rows[y]).charAt(x)] || "ground"
  }
  function walkable(x, y) {
    var t = TileArt.TERRAIN[terrainAt(x, y)]
    return t ? t.walk === true : false
  }
  function isEncounterTile(x, y) {
    var t = TileArt.TERRAIN[terrainAt(x, y)]
    return t ? t.encounter === true : false
  }

  function step(dx, dy) {
    if (root.screen !== "map") return
    var nx = root.px + dx, ny = root.py + dy
    if (!walkable(nx, ny)) { bump.restart(); return }
    root.px = nx; root.py = ny
    root.steps += 1
    root.hasMoved = true
    if (isEncounterTile(nx, ny)) {
      rustle.restart()
      sfx.play("rustle")
      if (Math.random() < Encounters.ENCOUNTER_CHANCE) root.beginEncounter()
      else { root.saveDirty = true; saveTimer.restart() }
    }
  }

  // --------------------------------------------------------------- encounter
  property var encSpecies: null
  property int encObserved: 0
  property string encStage: "appeared"
  property string encFlavour: ""

  function beginEncounter() {
    var s = Encounters.pick(root.creatures, "grass", ctx.snapshot)
    if (!s) return
    root.encSpecies = s
    root.encStage = "appeared"
    root.encObserved = root.record(s.id).observed
    root.encFlavour = Math.random() < 0.35 ? Encounters.flavourFor(ctx.snapshot) : ""
    var firstSighting = root.record(s.id).seen === 0
    root.screen = "encounter"
    sfx.play(firstSighting ? "discover" : "encounter")
    root.touchSave(function(n) {
      var rec = n.species[s.id] || { seen: 0, observed: 0, firstSeen: "" }
      rec.seen += 1
      if (!rec.firstSeen) rec.firstSeen = new Date().toISOString()
      n.species[s.id] = rec
      n.encounters = (n.encounters || 0) + 1
    })
    root.sawFirstEncounter = true
  }

  function observe() {
    var s = root.encSpecies
    if (!s) return
    var need = s.observationsRequired || 3
    root.touchSave(function(n) {
      var rec = n.species[s.id] || { seen: 1, observed: 0, firstSeen: new Date().toISOString() }
      if (rec.observed < need) rec.observed += 1
      n.species[s.id] = rec
    })
    root.encObserved = Math.min(root.record(s.id).observed, need)
    root.encStage = "entry"
    sfx.play(root.encObserved >= need ? "complete" : "page")
  }

  function toggleMute() {
    root.muted = !root.muted
    root.touchSave(function(n) { n.muted = root.muted })
  }

  function leaveEncounter() { root.encSpecies = null; root.screen = "map" }

  // ---------------------------------------------------------------- feedback
  property real bumpOffset: 0
  property real rustleAmount: 0
  SequentialAnimation {
    id: bump
    NumberAnimation { target: root; property: "bumpOffset"; to: 2; duration: 45 }
    NumberAnimation { target: root; property: "bumpOffset"; to: 0; duration: 70 }
  }
  SequentialAnimation {
    id: rustle
    NumberAnimation { target: root; property: "rustleAmount"; to: 1; duration: 70 }
    NumberAnimation { target: root; property: "rustleAmount"; to: 0; duration: 200 }
  }

  // --------------------------------------------------------------- lifecycle
  function open(payloadJson) {
    root.hour = new Date().getHours()
    root.palette = TileArt.paletteFor(root.phase)
    ctx.refresh()
    root.screen = "map"
    root.opened = true
    Qt.callLater(function() { keys.forceActiveFocus() })
  }
  function close() {
    root.opened = false
    if (root.saveDirty) { saveFile.setText(JSON.stringify(root.save, null, 2) + "\n"); root.saveDirty = false }
  }
  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function diag() {
    return "map=" + (mapData ? mapData.width + "x" + mapData.height : "null")
      + " species=" + creatures.length
      + " pos=" + px + "," + py + " terrain=" + terrainAt(px, py)
      + " steps=" + steps + " screen=" + screen
      + " discovered=" + discoveredCount() + "/" + totalSpecies()
      + " completed=" + completedCount()
      + " phase=" + phase + " muted=" + muted + " sfxReady=" + sfx.ready()
      + " | ctx " + ctx.summary()
  }

  // Which species are currently eligible, and at what weight. Handy for
  // checking that a context condition is doing what you think it is.
  function pool() {
    var ctxs = ctx.snapshot
    var el = Encounters.eligible(root.creatures, "grass", ctxs)
    var parts = []
    for (var i = 0; i < el.length; i++) parts.push(el[i].name + ":" + Encounters.weightFor(el[i], ctxs))
    var excluded = []
    for (var j = 0; j < root.creatures.length; j++) {
      var c = root.creatures[j]
      if (el.indexOf(c) < 0) excluded.push(c.name)
    }
    return "eligible(" + el.length + "): " + parts.join(", ")
         + "  ||  excluded(" + excluded.length + "): " + excluded.join(", ")
  }

  // Force an encounter, for testing the loop without walking for ten minutes.
  function forceEncounter() {
    if (root.screen !== "map") return "not on map"
    root.beginEncounter()
    return root.encSpecies ? root.encSpecies.name : "no eligible species"
  }

  // ------------------------------------------------------------------ chrome
  readonly property color scrimColor: Util.alpha(Color.background, 0.72)
  readonly property color frameColor: Util.alpha(Color.background, 0.98)
  readonly property color inkColor: Color.menu.text
  readonly property color accentColor: Color.accent
  readonly property color dimColor: Util.alpha(Color.menu.text, 0.45)
  readonly property color edgeColor: Util.alpha(Color.menu.border, 0.45)
  readonly property color rowFill: Util.alpha(Color.accent, 0.18)

  readonly property int tile: {
    var availW = (panel.width || 1280) * 0.82
    var availH = (panel.height || 720) * 0.70
    var cols = mapData ? mapData.width : 20
    var lines = mapData ? mapData.height : 12
    return Math.max(16, Math.min(48, Math.floor(Math.min(availW / cols, availH / lines) / 8) * 8))
  }
  readonly property int boardW: (mapData ? mapData.width : 20) * tile
  readonly property int boardH: (mapData ? mapData.height : 12) * tile

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omawild"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrimColor }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        var k = event.key
        event.accepted = true

        if (root.screen === "map") {
          // WASD keeps D as "move right", so the Field Guide lives on G / Tab.
          if (k === Qt.Key_Escape) root.dismiss()
          else if (k === Qt.Key_W || k === Qt.Key_Up)    root.step(0, -1)
          else if (k === Qt.Key_S || k === Qt.Key_Down)  root.step(0,  1)
          else if (k === Qt.Key_A || k === Qt.Key_Left)  root.step(-1, 0)
          else if (k === Qt.Key_D || k === Qt.Key_Right) root.step(1,  0)
          else if (k === Qt.Key_G || k === Qt.Key_Tab)   { guide.selectedIndex = 0; root.screen = "guide"; sfx.play("page") }
          else if (k === Qt.Key_M)                       root.toggleMute()
          else event.accepted = false

        } else if (root.screen === "encounter") {
          if (root.encStage === "appeared") {
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.observe()
            else if (k === Qt.Key_Escape || k === Qt.Key_R) root.leaveEncounter()
            else event.accepted = false
          } else {
            if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Escape)
              root.leaveEncounter()
            else event.accepted = false
          }

        } else if (root.screen === "guide") {
          if (k === Qt.Key_Escape || k === Qt.Key_G || k === Qt.Key_Tab) root.screen = "map"
          else if (k === Qt.Key_W || k === Qt.Key_Up)   { guide.move(-1); sfx.play("page") }
          else if (k === Qt.Key_S || k === Qt.Key_Down) { guide.move(1);  sfx.play("page") }
          else if (k === Qt.Key_M) root.toggleMute()
          else event.accepted = false
        }
      }
    }

    // ------------------------------------------------------------- the card
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: root.boardW + Style.space(24)
      height: header.height + root.boardH + footer.height + Style.space(24)
      color: root.frameColor
      border.width: 1
      border.color: root.edgeColor
      radius: Style.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        anchors.centerIn: parent
        spacing: 0

        Item {
          id: header
          width: root.boardW
          height: Style.space(30)
          Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: root.screen === "guide" ? "FIELD GUIDE" : "OMAWILD"
            color: root.accentColor
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.letterSpacing: 2
          }
          Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: root.discoveredCount() + " / " + root.totalSpecies()
                  + (root.screen === "guide" ? ("    " + root.completedCount() + " complete") : "")
            color: root.inkColor; opacity: 0.65
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        // ------------------------------------------------------------ board
        Item {
          width: root.boardW
          height: root.boardH
          clip: true

          // --- meadow
          Item {
            anchors.fill: parent
            visible: root.screen === "map"

            Ui.MapView {
              mapData: root.mapData
              palette: root.palette
              tile: root.tile
            }
            Rectangle {
              visible: root.rustleAmount > 0
              x: root.px * root.tile; y: root.py * root.tile
              width: root.tile; height: root.tile
              color: "#ffffff"; opacity: root.rustleAmount * 0.35
            }
            Ui.PixelSprite {
              rows: Sprites.PLAYER.down
              palette: Sprites.PLAYER.palette
              pixel: Math.max(2, Math.round(root.tile / 14))
              x: root.px * root.tile + (root.tile - width) / 2 + root.bumpOffset
              y: root.py * root.tile + root.tile - height
              Behavior on x { NumberAnimation { duration: 70 } }
              Behavior on y { NumberAnimation { duration: 70 } }
            }
          }

          // --- encounter
          Rectangle {
            anchors.fill: parent
            visible: root.screen === "encounter"
            // A darkened meadow rather than the flat daylight colour, so the
            // creature and the theme accent both stay readable.
            gradient: Gradient {
              GradientStop { position: 0.0; color: TileArt.shade(TileArt.skyFor(root.phase), 0.42, "#101820", 0.35) }
              GradientStop { position: 1.0; color: TileArt.shade(root.palette.ground ? root.palette.ground[0] : "#4a7a3c", 0.30, "#0a0f14", 0.45) }
            }
            Ui.EncounterView {
              anchors.fill: parent
              species: root.encSpecies
              observed: root.encObserved
              stage: root.encStage
              flavour: root.encFlavour
              ink: "#e8eef4"
              accent: root.accentColor
              dim: Qt.rgba(0.91, 0.93, 0.96, 0.5)
              unit: Math.max(4, Math.round(root.tile / 5))
            }
          }

          // --- field guide
          Item {
            anchors.fill: parent
            anchors.margins: Style.space(6)
            visible: root.screen === "guide"
            Ui.FieldGuideView {
              id: guide
              anchors.fill: parent
              creatures: root.creatures
              save: root.save
              ink: root.inkColor
              accent: root.accentColor
              dim: root.dimColor
              rowFill: root.rowFill
            }
          }
        }

        Item {
          id: footer
          width: root.boardW
          height: Style.space(26)
          Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: {
              if (root.screen === "guide") return "W/S  browse      ESC  back"
              if (root.screen === "encounter")
                return root.encStage === "appeared" ? "ENTER  observe      ESC  leave"
                                                    : "ENTER  back to the meadow"
              if (!root.hasMoved) return "WASD / ARROWS TO MOVE"
              if (!root.sawFirstEncounter) return "walk into the tall grass"
              return "G  field guide      ESC  close"
            }
            color: root.inkColor
            opacity: root.hasMoved ? 0.45 : 0.8
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            Behavior on opacity { NumberAnimation { duration: 300 } }
          }
          Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: root.screen === "map" ? root.phase : ""
            color: root.inkColor; opacity: 0.35
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
