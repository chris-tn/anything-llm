import i18n from "@/i18n";
import { resources as languages } from "@/locales/resources";

export function useLanguageOptions() {
  const supportedLanguages = Object.keys(languages);
  const languageNames = new Intl.DisplayNames(supportedLanguages, {
    type: "language",
  });
  const changeLanguage = (newLang = "vn") => {
    if (!Object.keys(languages).includes(newLang)) return false;
    i18n.changeLanguage(newLang);
  };

  return {
    currentLanguage: i18n.language || "vn",
    supportedLanguages,
    getLanguageName: (lang = "vn") => languageNames.of(lang),
    changeLanguage,
  };
}
