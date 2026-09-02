import QtQuick
import QtMultimedia

// Small synthesized sound set. Everything is short and quiet by design.
Item {
  id: root
  property bool muted: false
  property real volume: 0.30

  function play(name) {
    if (root.muted) return
    var e = null
    if (name === "rustle") e = rustleSfx
    else if (name === "encounter") e = encounterSfx
    else if (name === "discover") e = discoverSfx
    else if (name === "complete") e = completeSfx
    else if (name === "page") e = pageSfx
    if (e && e.status === SoundEffect.Ready) e.play()
  }

  function ready() { return rustleSfx.status === SoundEffect.Ready }

  SoundEffect { id: rustleSfx;   source: Qt.resolvedUrl("../sounds/rustle.wav");    volume: root.volume }
  SoundEffect { id: encounterSfx; source: Qt.resolvedUrl("../sounds/encounter.wav"); volume: root.volume }
  SoundEffect { id: discoverSfx; source: Qt.resolvedUrl("../sounds/discover.wav");  volume: root.volume }
  SoundEffect { id: completeSfx; source: Qt.resolvedUrl("../sounds/complete.wav");  volume: root.volume }
  SoundEffect { id: pageSfx;     source: Qt.resolvedUrl("../sounds/page.wav");      volume: root.volume * 0.8 }
}
