.pragma library

// Terrain behaviour. Only `grass` triggers encounters; everything else is
// either walkable scenery or a wall.
var TERRAIN = {
  ground:   { walk: true,  encounter: false },
  grass:    { walk: true,  encounter: true  },
  path:     { walk: true,  encounter: false },
  tree:     { walk: false, encounter: false },
  water:    { walk: false, encounter: false },
  rock:     { walk: false, encounter: false },
  ruin:     { walk: false, encounter: false },
  artifact: { walk: false, encounter: false }
}

// 8x8 patterns. Each character indexes that terrain's colour ramp.
var TILES = {
  ground: [
    "00000000","00000100","00000000","00100000",
    "00000000","00000010","00000000","01000000"
  ],
  grass: [
    "00000000","00200020","01200120","01100110",
    "00000000","20002000","21002100","11001100"
  ],
  path: [
    "11111111","11211111","11111121","11111111",
    "12111111","11111211","11111111","11121111"
  ],
  tree: [
    "00111100","01122110","11222211","11222211",
    "01122110","00133100","00033000","00033000"
  ],
  water: [
    "11111111","11111111","12211221","11111111",
    "11111111","21122112","11111111","11111111"
  ],
  rock: [
    "00000000","00011100","00122110","01222110",
    "01221110","11111110","01111100","00000000"
  ],
  ruin: [
    "00000000","00100100","00100100","01110110",
    "00100100","01110110","00100100","01111110"
  ],
  artifact: [
    "00000000","01111110","01222210","01233210",
    "01222210","01111110","00111100","00000000"
  ]
}

// Daytime ramps. Evening and night are derived, so there is one palette to tune.
var DAY = {
  ground:   ["#4a7a3c", "#57894a", "#3f6a33", "#000000"],
  grass:    ["#3f6f33", "#5b9c46", "#77bd57", "#000000"],
  path:     ["#7a6a48", "#8a7a56", "#9c8c66", "#000000"],
  tree:     ["#4a7a3c", "#245c2c", "#357a3a", "#5a3f28"],
  water:    ["#245a80", "#2f6f9c", "#57a3cc", "#000000"],
  rock:     ["#4a7a3c", "#6a6f76", "#8b9098", "#000000"],
  ruin:     ["#4a7a3c", "#8d8a80", "#a5a298", "#000000"],
  artifact: ["#4a7a3c", "#2a2f36", "#3c444e", "#7ee0a0"]
}

function _hex(c) {
  var v = String(c).replace("#", "")
  return [parseInt(v.substr(0,2),16), parseInt(v.substr(2,2),16), parseInt(v.substr(4,2),16)]
}
function _str(r,g,b) {
  function p(n){ n = Math.max(0, Math.min(255, Math.round(n))); var s = n.toString(16); return s.length<2?"0"+s:s }
  return "#" + p(r) + p(g) + p(b)
}

// Darken toward black, then pull a fraction of the way to a tint colour.
function shade(hex, factor, tint, amount) {
  var c = _hex(hex)
  var r = c[0]*factor, g = c[1]*factor, b = c[2]*factor
  if (tint && amount > 0) {
    var t = _hex(tint)
    r += (t[0]-r)*amount; g += (t[1]-g)*amount; b += (t[2]-b)*amount
  }
  return _str(r,g,b)
}

var PHASES = {
  day:     { factor: 1.00, tint: null,      amount: 0.00, sky: "#6fa052" },
  evening: { factor: 0.82, tint: "#ff9a4a", amount: 0.20, sky: "#7a6a52" },
  night:   { factor: 0.50, tint: "#3a5aa0", amount: 0.32, sky: "#2a3350" }
}

function phaseFor(hour) {
  if (hour >= 20 || hour < 6) return "night"
  if (hour >= 17) return "evening"
  return "day"
}

// Full palette set for a phase, cached by the caller.
function paletteFor(phase) {
  var p = PHASES[phase] || PHASES.day
  var out = {}
  for (var key in DAY) {
    var ramp = DAY[key], next = []
    for (var i = 0; i < ramp.length; i++) next.push(shade(ramp[i], p.factor, p.tint, p.amount))
    out[key] = next
  }
  return out
}

function skyFor(phase) { return (PHASES[phase] || PHASES.day).sky }
