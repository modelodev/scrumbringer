import scrumbringer_client/api/workflows/rule_metrics

pub fn calendar_date_range_query_uses_html_date_values_test() {
  let range = rule_metrics.calendar_date_range("2026-01-01", "2026-01-31")

  let assert "?from=2026-01-01&to=2026-01-31" =
    rule_metrics.calendar_date_range_query(range)
}
