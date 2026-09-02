.pragma library

// Base chance per step on encounter terrain. Low enough that walking into
// grass keeps its anticipation.
var ENCOUNTER_CHANCE = 0.11

function hourInRange(h, from, to) {
  if (from === undefined || to === undefined) return true
  if (from <= to) return h >= from && h <= to
  return h >= from || h <= to            // wraps past midnight
}

// A tiny fixed vocabulary, deliberately not a scripting engine.
function condMet(cond, ctx) {
  if (!cond) return true
  if (cond.hourFrom !== undefined && !hourInRange(ctx.hour, cond.hourFrom, cond.hourTo)) return false
  if (cond.mediaPlaying !== undefined && !!ctx.mediaPlaying !== !!cond.mediaPlaying) return false
  if (cond.onBattery !== undefined) {
    if (ctx.onBattery === null || ctx.onBattery === undefined) return false
    if (!!ctx.onBattery !== !!cond.onBattery) return false
  }
  if (cond.networkOnline !== undefined && !!ctx.networkOnline !== !!cond.networkOnline) return false
  if (cond.focusedIsBrowser !== undefined && !!ctx.focusedIsBrowser !== !!cond.focusedIsBrowser) return false
  if (cond.gitDirty !== undefined) {
    if (ctx.gitDirty === null || ctx.gitDirty === undefined) return false
    if (!!ctx.gitDirty !== !!cond.gitDirty) return false
  }
  if (cond.uptimeHoursMin !== undefined && !(ctx.uptimeHours >= cond.uptimeHoursMin)) return false
  if (cond.memoryPercentMin !== undefined && !(ctx.memoryPercent >= cond.memoryPercentMin)) return false
  return true
}

function eligible(species, terrain, ctx) {
  var out = []
  for (var i = 0; i < species.length; i++) {
    var s = species[i]
    if (!s.terrain || s.terrain.indexOf(terrain) < 0) continue
    if (!condMet(s.conditions, ctx)) continue
    out.push(s)
  }
  return out
}

function weightFor(s, ctx) {
  var w = s.baseWeight || 1
  var mods = s.modifiers || []
  for (var i = 0; i < mods.length; i++) {
    if (condMet(mods[i].when, ctx)) w *= (mods[i].multiplier || 1)
  }
  return w
}

function pick(species, terrain, ctx, roll) {
  var pool = eligible(species, terrain, ctx)
  if (!pool.length) return null
  var weights = [], total = 0
  for (var i = 0; i < pool.length; i++) {
    var w = weightFor(pool[i], ctx)
    weights.push(w); total += w
  }
  var r = (roll === undefined ? Math.random() : roll) * total
  for (var j = 0; j < pool.length; j++) {
    r -= weights[j]
    if (r <= 0) return pool[j]
  }
  return pool[pool.length - 1]
}

// Atmospheric one-liners. Used sparingly.
var FLAVOUR = [
  "Something moved in the grass.",
  "You hear a faint clicking sound.",
  "The air feels strangely electric.",
  "For a moment, the screen flickers.",
  "Something is humming along with the music.",
  "The grass leans the wrong way.",
  "Somewhere nearby, something is counting."
]

function flavourFor(ctx, roll) {
  var pool = []
  for (var i = 0; i < FLAVOUR.length; i++) {
    var line = FLAVOUR[i]
    if (line.indexOf("music") >= 0 && !ctx.mediaPlaying) continue
    if (line.indexOf("electric") >= 0 && !ctx.onBattery) continue
    pool.push(line)
  }
  if (!pool.length) return ""
  return pool[Math.floor((roll === undefined ? Math.random() : roll) * pool.length) % pool.length]
}
