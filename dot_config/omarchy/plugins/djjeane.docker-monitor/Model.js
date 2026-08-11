function parseData(raw) {
  try {
    return JSON.parse(String(raw || "{}"))
  } catch (e) {
    return {}
  }
}

function stateColor(state) {
  if (state === "running") return "#22c55e"
  if (state === "paused") return "#eab308"
  if (state === "restarting") return "#3b82f6"
  return "#6b7280"
}

function stateGlyph(state) {
  if (state === "running") return "●"
  if (state === "paused") return "◫"
  if (state === "restarting") return "↻"
  if (state === "exited") return "○"
  if (state === "dead") return "✕"
  if (state === "created") return "◌"
  return "?"
}

function cpuColor(pct) {
  if (pct >= 80) return "#ef4444"
  if (pct >= 50) return "#eab308"
  return ""
}

function memColor(pct) {
  if (pct >= 80) return "#ef4444"
  if (pct >= 50) return "#eab308"
  return ""
}

function isUnhealthy(status) {
  return String(status || "").indexOf("unhealthy") >= 0
}

function shortImage(image) {
  var img = image || ""
  var slash = img.lastIndexOf("/")
  if (slash >= 0) img = img.substring(slash + 1)
  var colon = img.indexOf(":")
  if (colon >= 0) img = img.substring(0, colon)
  return img
}

function detectChanges(prevStates, containers) {
  var changes = []
  if (!prevStates || !containers) return changes
  for (var i = 0; i < containers.length; i++) {
    var c = containers[i]
    var name = c.name
    var prev = prevStates[name]
    if (!prev) continue

    if (prev.state === "running" && c.state === "exited")
      changes.push({ type: "stopped", name: name, message: name + " has stopped" })
    else if (prev.state === "running" && c.state === "dead")
      changes.push({ type: "stopped", name: name, message: name + " is dead" })
    else if (!isUnhealthy(prev.status) && isUnhealthy(c.status))
      changes.push({ type: "unhealthy", name: name, message: name + " is unhealthy" })
    else if (prev.state !== "running" && c.state === "running")
      changes.push({ type: "started", name: name, message: name + " is now running" })
  }
  return changes
}

function buildStateMap(containers) {
  var map = {}
  if (!containers) return map
  for (var i = 0; i < containers.length; i++) {
    var c = containers[i]
    map[c.name] = { state: c.state, status: c.status }
  }
  return map
}

if (typeof module !== "undefined") {
  module.exports = {
    parseData: parseData,
    stateColor: stateColor,
    stateGlyph: stateGlyph,
    cpuColor: cpuColor,
    memColor: memColor,
    isUnhealthy: isUnhealthy,
    shortImage: shortImage,
    detectChanges: detectChanges,
    buildStateMap: buildStateMap
  }
}
