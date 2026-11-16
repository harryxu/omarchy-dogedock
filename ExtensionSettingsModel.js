function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function readFields(data) {
  if (data === undefined) return []
  if (!Array.isArray(data)) throw new Error("settings must be an array")
  var keys = new Set()
  return data.map(function(field) {
    if (!isObject(field) || typeof field.key !== "string" || !/^[a-zA-Z][a-zA-Z0-9_-]*$/.test(field.key)
      || keys.has(field.key) || typeof field.label !== "string" || !field.label.trim()
      || ["string", "boolean", "number", "choice", "directory"].indexOf(field.type) < 0
      || (field.multiple !== undefined && typeof field.multiple !== "boolean")) {
      throw new Error("invalid settings field " + JSON.stringify(field))
    }
    keys.add(field.key)
    if (field.type === "choice") {
      var options = new Set()
      if (!Array.isArray(field.options) || !field.options.length || field.options.some(function(option) {
        if (!isObject(option) || typeof option.value !== "string" || !option.value || options.has(option.value)
          || typeof option.label !== "string" || !option.label.trim()) return true
        options.add(option.value)
        return false
      })) throw new Error("invalid options for " + field.key)
    }
    var checked = check(field, field.default, undefined)
    if (checked.invalid) throw new Error("invalid default for " + field.key)
    return Object.assign({}, field, { default: checked.value, multiple: field.multiple === true })
  })
}

function itemValue(field, value) {
  switch (field.type) {
  case "string":
    return typeof value === "string" ? value : undefined
  case "boolean":
    return typeof value === "boolean" ? value : undefined
  case "number":
    return typeof value === "number" && Number.isFinite(value) ? value : undefined
  case "choice":
    return field.options.some(function(option) { return option.value === value }) ? value : undefined
  case "directory":
    if (value === "" && !field.multiple) return value
    return typeof value === "string" && value.startsWith("/") && !/\x00/.test(value)
      ? value.replace(/\/+$/, "") || "/" : undefined
  }
  return undefined
}

function check(field, value, fallback) {
  if (!field.multiple) {
    var normalized = itemValue(field, value)
    return normalized === undefined ? { value: fallback, invalid: true } : { value: normalized, invalid: false }
  }
  if (!Array.isArray(value)) return { value: fallback, invalid: true }
  var items = []
  var seen = new Set()
  for (var item of value) {
    var normalizedItem = itemValue(field, item)
    if (normalizedItem === undefined || (field.type === "directory" && seen.has(normalizedItem))) continue
    items.push(normalizedItem)
    seen.add(normalizedItem)
  }
  var invalid = items.length !== value.length
  return { value: invalid && items.length === 0 ? fallback : items, invalid: invalid }
}

function resolve(fields, saved) {
  var values = Object.create(null)
  var invalid = Object.create(null)
  var malformed = saved !== undefined && !isObject(saved)
  for (var field of fields) {
    var hasValue = !malformed && saved !== undefined && Object.prototype.hasOwnProperty.call(saved, field.key)
    var checked = hasValue ? check(field, saved[field.key], field.default) : { value: field.default, invalid: malformed }
    values[field.key] = checked.value
    if (checked.invalid) invalid[field.key] = true
  }
  return { values: values, invalid: invalid }
}
