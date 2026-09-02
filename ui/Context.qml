import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Reads a handful of harmless local signals on a slow timer. Everything stays
// on this machine; nothing here is ever sent anywhere.
Item {
  id: root

  property string gitWatchPath: Quickshell.env("HOME") + "/Work"

  property int  hour: new Date().getHours()
  property var  onBattery: null
  property int  batteryPercent: 100
  property int  uptimeHours: 0
  property int  memoryPercent: 0
  property bool networkOnline: false
  property string focusedClass: ""
  property string theme: ""
  property var  gitDirty: null

  readonly property bool mediaPlaying: {
    var ps = (Mpris.players && Mpris.players.values) || []
    for (var i = 0; i < ps.length; i++) if (ps[i] && ps[i].isPlaying) return true
    return false
  }
  readonly property bool focusedIsBrowser: {
    var c = String(focusedClass).toLowerCase()
    return c.indexOf("chrom") >= 0 || c.indexOf("firefox") >= 0 || c.indexOf("brave") >= 0
        || c.indexOf("zen") >= 0 || c.indexOf("edge") >= 0 || c.indexOf("librewolf") >= 0
  }

  // Plain object handed to the encounter rules.
  readonly property var snapshot: ({
    hour: hour, onBattery: onBattery, batteryPercent: batteryPercent,
    uptimeHours: uptimeHours, memoryPercent: memoryPercent,
    networkOnline: networkOnline, focusedClass: focusedClass,
    focusedIsBrowser: focusedIsBrowser, mediaPlaying: mediaPlaying,
    theme: theme, gitDirty: gitDirty
  })

  function summary() {
    return "hour=" + hour + " battery=" + onBattery + "/" + batteryPercent
      + " uptimeH=" + uptimeHours + " mem=" + memoryPercent + "%"
      + " net=" + networkOnline + " focused=" + focusedClass
      + " browser=" + focusedIsBrowser + " media=" + mediaPlaying
      + " theme=" + theme + " gitDirty=" + gitDirty
  }

  function refresh() {
    root.hour = new Date().getHours()
    if (!probe.running) probe.running = true
  }

  Component.onCompleted: refresh()
  Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }

  Process {
    id: probe
    command: ["bash", "-lc", `
      ac=""; for f in /sys/class/power_supply/A*/online; do [ -r "$f" ] && ac=$(cat "$f") && break; done
      cap=""; for f in /sys/class/power_supply/BAT*/capacity; do [ -r "$f" ] && cap=$(cat "$f") && break; done
      up=$(awk '{printf "%d", $1/3600}' /proc/uptime 2>/dev/null || echo 0)
      mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t>0) printf "%d", (t-a)*100/t; else print 0}' /proc/meminfo)
      # Routing-table check only: this never sends a packet.
      if ip route get 1.1.1.1 >/dev/null 2>&1; then net=true; else net=false; fi
      cls=$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*"class": "\\([^"]*\\)".*/\\1/p' | head -1)
      thm=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
      gd=null
      if [ -d "$1/.git" ]; then
        if [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; then gd=true; else gd=false; fi
      fi
      printf '{"ac":"%s","cap":"%s","up":%s,"mem":%s,"net":%s,"cls":"%s","theme":"%s","gitDirty":%s}\\n' \
        "$ac" "$cap" "\${up:-0}" "\${mem:-0}" "$net" "$cls" "$thm" "$gd"
    `, "bash", root.gitWatchPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.onBattery     = d.ac === "" ? null : (d.ac === "0")
          root.batteryPercent = d.cap === "" ? 100 : parseInt(d.cap, 10)
          root.uptimeHours   = d.up | 0
          root.memoryPercent = d.mem | 0
          root.networkOnline = d.net === true
          root.focusedClass  = String(d.cls || "")
          root.theme         = String(d.theme || "")
          root.gitDirty      = (d.gitDirty === null) ? null : !!d.gitDirty
        } catch (e) { console.warn("omawild: context parse failed", e, text) }
      }
    }
  }
}
