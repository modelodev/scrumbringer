import scrumbringer_client/i18n/en
import scrumbringer_client/i18n/es
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text.{type Text}

pub fn t(locale: Locale, text: Text) -> String {
  case locale {
    locale.Es -> es.translate(text)
    locale.En -> en.translate(text)
  }
}
