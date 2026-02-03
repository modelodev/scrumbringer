function formatDate(d) {
  return d.toISOString().split("T")[0]
}

export function date_today() {
  return formatDate(new Date())
}

export function date_days_ago(days) {
  const d = new Date()
  d.setDate(d.getDate() - days)
  return formatDate(d)
}
