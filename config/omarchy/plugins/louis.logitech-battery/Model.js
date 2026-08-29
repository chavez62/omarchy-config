function iconFor(kind) {
  if (kind === "mouse") return "󰍽"
  if (kind === "keyboard") return "󰌌"
  if (kind === "headset" || kind === "headphones") return "󰋋"
  if (kind === "gaming_input") return "󰊴"
  return "󰂂"
}

function shortName(name, kind) {
  var text = String(name || "").replace(/^Logitech\s+/i, "").trim()
  if (/G733|G633|G635|G933|G935/i.test(text)) return "G733"
  if (/g\s*pro/i.test(text)) return "G Pro"
  text = text.replace(/\s+Gaming Headset$/i, "")
  return text || String(kind || "Device").replace(/_/g, " ")
}

function inferKind(kind, name) {
  var text = String(name || "").toLowerCase()
  if (text.indexOf("mouse") !== -1) return "mouse"
  if (text.indexOf("keyboard") !== -1) return "keyboard"
  if (text.indexOf("headset") !== -1 || text.indexOf("headphone") !== -1) return "headset"
  return kind || "peripheral"
}

function kindFromType(type, types) {
  var t = types || {}
  if (type === t.Mouse) return "mouse"
  if (type === t.Keyboard) return "keyboard"
  if (type === t.Headset || type === t.Headphones) return "headset"
  if (type === t.GamingInput) return "gaming_input"
  return "peripheral"
}

function stateFromEnum(state, states) {
  var s = states || {}
  if (state === s.Charging || state === s.PendingCharge) return "charging"
  if (state === s.Discharging || state === s.PendingDischarge) return "discharging"
  if (state === s.FullyCharged) return "fully_charged"
  if (state === s.Empty) return "empty"
  if (state === s.Unknown) return "unknown"
  return "unknown"
}

function asPercent(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return null
  if (n <= 1) return Math.round(n * 100)
  return Math.round(n)
}

function identityKey(device) {
  var serial = String(device && device.serial ? device.serial : "").trim().toLowerCase()
  if (serial) return "serial:" + serial
  var name = String(device && device.name ? device.name : "").toLowerCase()
  name = name.replace(/logitech|wireless|gaming|mouse|keyboard|headset|headphones/g, " ")
  name = name.replace(/[^a-z0-9]+/g, " ").trim()
  return "name:" + (name || String(device && device.id ? device.id : ""))
}

function quality(device) {
  var score = 0
  var state = device && device.state ? device.state : "unknown"
  if (state !== "unknown" && state !== "") score += 10
  if (state === "charging" || state === "discharging" || state === "fully_charged") score += 5
  if (device && device.present) score += 2
  if (device && typeof device.percentage === "number") score += 2
  if (device && device.kind === "mouse") score += 1
  return score
}

function prefer(left, right) {
  var winner = quality(right) > quality(left) ? right : left
  winner = Object.assign({}, winner)
  if (left.kind === "mouse" || right.kind === "mouse"
      || inferKind(left.kind, left.name) === "mouse"
      || inferKind(right.kind, right.name) === "mouse")
    winner.kind = "mouse"
  else
    winner.kind = inferKind(winner.kind, winner.name)
  winner.charging = winner.state === "charging"
  return winner
}

function dedupe(devices) {
  var list = Array.isArray(devices) ? devices : []
  var chosen = {}
  var order = []
  for (var i = 0; i < list.length; i++) {
    var device = list[i]
    if (!device) continue
    var key = identityKey(device)
    if (!chosen[key]) {
      chosen[key] = device
      order.push(key)
    } else {
      chosen[key] = prefer(chosen[key], device)
    }
  }
  return order.map(function(key) { return chosen[key] })
}

function snapshotUpower(d, types, states) {
  if (!d) return null
  if (d.isLaptopBattery === true || d.powerSupply === true) return null

  var model = String(d.model || "")
  var path = String(d.nativePath || "")
  var kind = inferKind(kindFromType(d.type, types), model)
  var logitech = /logitech|hidpp/i.test(model + " " + path)
  if (kind === "peripheral" && !logitech) return null
  if (!logitech && kind !== "mouse" && kind !== "keyboard" && kind !== "headset" && kind !== "headphones" && kind !== "gaming_input")
    return null

  var present = d.isPresent === true
  var percentage = asPercent(d.percentage)
  var state = stateFromEnum(d.state, states)
  var minutes = null
  var empty = Number(d.timeToEmpty)
  if (isFinite(empty) && empty > 60) minutes = Math.round(empty / 60)

  return {
    id: path || model || "upower",
    kind: kind,
    name: shortName(model, kind),
    serial: "",
    percentage: present ? percentage : null,
    state: state,
    present: present,
    charging: state === "charging",
    minutes: present && state === "discharging" ? minutes : null,
    source: "upower"
  }
}

function collectUpower(model, types, states) {
  var out = []
  if (!model) return out
  var values = model.values
  var n = 0
  if (values && values.length !== undefined) n = values.length
  else if (model.count !== undefined) n = model.count
  for (var i = 0; i < n; i++) {
    var d = values ? values[i] : (model.get ? model.get(i) : null)
    var snap = snapshotUpower(d, types, states)
    if (snap) out.push(snap)
  }
  return dedupe(out)
}

function parseHeadset(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  var payload
  try {
    payload = JSON.parse(text)
  } catch (e) {
    return null
  }
  var items = payload && payload.devices ? payload.devices : []
  var out = []
  for (var i = 0; i < items.length; i++) {
    var item = items[i] || {}
    var battery = item.battery || {}
    var status = battery.status || "BATTERY_UNAVAILABLE"
    var present = status !== "BATTERY_UNAVAILABLE"
    var charging = status === "BATTERY_CHARGING"
    var product = item.product || item.device || "Headset"
    var minutes = battery.time_to_empty_min
    if (typeof minutes !== "number" || minutes < 0) minutes = null
    else minutes = Math.round(minutes)
    var level = battery.level
    var percentage = null
    if (typeof level === "number" && level >= 0) percentage = Math.round(level)
    out.push({
      id: "headsetcontrol:" + (item.id_vendor || "") + ":" + (item.id_product || ""),
      kind: "headset",
      name: shortName(product, "headset"),
      serial: item.serial || "",
      percentage: present ? percentage : null,
      state: charging ? "charging" : (present ? "discharging" : "unavailable"),
      present: present,
      charging: charging,
      minutes: present && !charging ? minutes : null,
      source: "headsetcontrol"
    })
  }
  return out
}

function parseSnapshot(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  var payload
  try {
    payload = JSON.parse(text)
  } catch (e) {
    return null
  }
  if (!payload || !Array.isArray(payload.devices)) return null
  return dedupe(payload.devices)
}

function merge(upowerDevices, headsetDevices) {
  var mice = dedupe(upowerDevices)
  var headsets = Array.isArray(headsetDevices) ? headsetDevices : []
  if (headsets.length > 0)
    mice = mice.filter(function(d) { return d.kind !== "headset" && d.kind !== "headphones" })
  return mice.concat(headsets)
}

function liveDevices(devices) {
  var list = Array.isArray(devices) ? devices : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    if (!d || d.present !== true) continue
    if (typeof d.percentage !== "number") continue
    out.push(d)
  }
  return out
}

function panelDevices(devices) {
  return Array.isArray(devices) ? devices : []
}

function isLow(device, threshold) {
  var limit = threshold === undefined ? 20 : threshold
  return !!(device && device.present && typeof device.percentage === "number" && device.percentage <= limit)
}

function isCritical(device) {
  return isLow(device, 10)
}

function anyLow(devices, threshold) {
  var list = liveDevices(devices)
  for (var i = 0; i < list.length; i++) {
    if (isLow(list[i], threshold)) return true
  }
  return false
}

function percentText(device) {
  if (!device || typeof device.percentage !== "number") return "—"
  return Math.round(device.percentage) + "%"
}

function stateLabel(device) {
  if (!device) return ""
  if (device.present !== true) return "Offline"
  var state = String(device.state || "")
  if (state === "charging") return "Charging"
  if (state === "fully_charged") return "Fully charged"
  if (state === "discharging") return "Discharging"
  if (state === "unavailable" || state === "empty") return "Offline"
  return ""
}

function formatMinutes(mins) {
  if (typeof mins !== "number" || mins < 0) return ""
  var total = Math.round(mins)
  var hours = Math.floor(total / 60)
  var minutes = total % 60
  if (hours <= 0) return minutes + "m left"
  return hours + "h " + minutes + "m left"
}

function detailLine(device) {
  if (!device) return ""
  if (device.present !== true) return "Offline"
  if (device.state === "charging") return "Charging"
  if (device.state === "fully_charged") return "Fully charged"
  var remaining = formatMinutes(device.minutes)
  if (remaining) return remaining
  if (device.state === "discharging") return "Discharging"
  return ""
}

function lowestLive(devices) {
  var list = liveDevices(devices)
  if (list.length === 0) return null
  var best = list[0]
  for (var i = 1; i < list.length; i++) {
    if (list[i].percentage < best.percentage) best = list[i]
  }
  return best
}

function barItems(devices, showAllPercentages) {
  var list = liveDevices(devices)
  var lowest = lowestLive(devices)
  var out = []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    out.push({
      id: d.id,
      kind: d.kind,
      name: d.name,
      icon: iconFor(d.kind),
      percentText: percentText(d),
      showPercent: showAllPercentages === true,
      charging: d.charging === true || d.state === "charging",
      low: isLow(d, 20),
      critical: isCritical(d),
      percentage: d.percentage,
      isLowest: !!(lowest && d.id === lowest.id)
    })
  }
  return out
}

function compactPercent(devices) {
  var lowest = lowestLive(devices)
  return lowest ? percentText(lowest) : ""
}

function compactUrgent(devices) {
  var lowest = lowestLive(devices)
  return !!(lowest && isLow(lowest, 20))
}

function tooltip(devices) {
  var list = panelDevices(devices)
  if (list.length === 0) return "No Logitech batteries"
  var lines = []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    var extra = detailLine(d)
    lines.push(d.name + "  " + percentText(d) + (extra ? " · " + extra : ""))
  }
  return lines.join("\n")
}

function applyNotices(devices, notified) {
  var prev = notified && typeof notified === "object" ? notified : {}
  var notices = []
  var next = {}
  var list = Array.isArray(devices) ? devices : []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    var id = String(d && (d.id || d.name) || i)
    var flags = prev[id] ? { t20: !!prev[id].t20, t10: !!prev[id].t10 } : { t20: false, t10: false }
    if (!d || d.present !== true || typeof d.percentage !== "number") {
      next[id] = { t20: false, t10: false }
      continue
    }
    var pct = d.percentage
    if (pct > 25) flags.t20 = false
    if (pct > 15) flags.t10 = false
    if (pct <= 10 && !flags.t10) {
      notices.push({ id: id, name: d.name, kind: d.kind, percentage: pct, urgency: "critical", threshold: 10 })
      flags.t10 = true
      flags.t20 = true
    } else if (pct <= 20 && !flags.t20) {
      notices.push({ id: id, name: d.name, kind: d.kind, percentage: pct, urgency: "normal", threshold: 20 })
      flags.t20 = true
    }
    next[id] = flags
  }
  return { notified: next, notices: notices }
}

if (typeof module !== "undefined") {
  module.exports = {
    iconFor: iconFor,
    shortName: shortName,
    inferKind: inferKind,
    collectUpower: collectUpower,
    snapshotUpower: snapshotUpower,
    parseHeadset: parseHeadset,
    parseSnapshot: parseSnapshot,
    merge: merge,
    dedupe: dedupe,
    liveDevices: liveDevices,
    panelDevices: panelDevices,
    isLow: isLow,
    isCritical: isCritical,
    anyLow: anyLow,
    percentText: percentText,
    stateLabel: stateLabel,
    formatMinutes: formatMinutes,
    detailLine: detailLine,
    lowestLive: lowestLive,
    barItems: barItems,
    compactPercent: compactPercent,
    compactUrgent: compactUrgent,
    tooltip: tooltip,
    applyNotices: applyNotices
  }
}
