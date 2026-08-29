.pragma library

function parseSnapshot(raw) {
  if (!raw) return null
  try {
    var payload = JSON.parse(String(raw))
    var devices = payload && payload.devices ? payload.devices : []
    return Array.isArray(devices) ? devices : []
  } catch (e) {
    return null
  }
}

function primary(devices) {
  if (!devices || devices.length === 0) return null
  return devices[0]
}

function dpiText(device) {
  if (!device || typeof device.dpi !== "number") return ""
  return String(device.dpi)
}

function compactDpi(devices) {
  return dpiText(primary(devices))
}

// Stage list with an `active` flag folded in, for the panel.
function stagesFor(device) {
  if (!device || !device.stages) return []
  var out = []
  for (var i = 0; i < device.stages.length; i++) {
    var stage = device.stages[i]
    out.push({
      index: stage.index,
      dpi: stage.dpi,
      isDefault: stage["default"] === true,
      active: stage.index === device.activeIndex
    })
  }
  return out
}

function nextIndex(device) {
  var stages = stagesFor(device)
  if (stages.length === 0) return null
  for (var i = 0; i < stages.length; i++) {
    if (stages[i].active) return stages[(i + 1) % stages.length].index
  }
  return stages[0].index
}

function rateText(device) {
  if (!device || typeof device.rate !== "number") return ""
  return device.rate + " Hz"
}

function tooltip(devices) {
  var device = primary(devices)
  if (!device) return "No libratbag mouse detected"
  var parts = [device.name]
  if (typeof device.dpi === "number") parts.push(device.dpi + " DPI")
  var rate = rateText(device)
  if (rate) parts.push(rate)
  return parts.join("  ·  ")
}

// Rough visual weight of a stage relative to the largest one, for the bars.
function fraction(stage, stages) {
  if (!stage || !stages || stages.length === 0) return 0
  var max = 0
  for (var i = 0; i < stages.length; i++) max = Math.max(max, stages[i].dpi || 0)
  if (max <= 0) return 0
  return Math.max(0.04, Math.min(1, stage.dpi / max))
}
