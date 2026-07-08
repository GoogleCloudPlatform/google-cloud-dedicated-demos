/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
// Frontend Internationalization Engine matching Tax-Office pattern
window.i18n = {
  dictionary: {},
  currentLang: "en",
  t: function (key, replacementMap) {
    let text = this.dictionary[key] || key;
    if (replacementMap) {
      for (const k in replacementMap) {
        text = text.replaceAll(k, replacementMap[k]);
      }
    }
    return text;
  },
  applyTranslations: function () {
    const elements = document.querySelectorAll("[data-i18n], [data-type]");
    elements.forEach((el) => {
      const key = el.getAttribute("data-i18n") || el.getAttribute("data-type");
      const target = el.getAttribute("data-i18n-target") || "text";
      const translation = this.t(key);

      if (translation && translation !== key) {
        if (target === "placeholder" || el.tagName === "INPUT") {
          el.placeholder = translation;
        } else if (target === "title") {
          el.title = translation;
        } else if (target === "html") {
          el.innerHTML = translation;
        } else {
          el.textContent = translation;
        }
      }
    });

    if (this.dictionary["PAGE_TITLE"]) {
      document.title = this.t("PAGE_TITLE");
    }
  },
};

document.addEventListener("DOMContentLoaded", async function () {
  // Determine stored or URL or default language
  const params = new URLSearchParams(window.location.search);
  let lang = params.get("lang");
  if (!lang) {
    lang = localStorage.getItem("ui_lang");
  }
  if (!lang) {
    const browserLang = (navigator.language || "fr").substring(0, 2).toLowerCase();
    const supportedLangs = ["en", "fr", "de"];
    lang = supportedLangs.includes(browserLang) ? browserLang : "fr";
  }
  window.i18n.currentLang = lang;

  // Fetch available languages and populate switchers
  try {
    const res = await fetch("/api/i18n/languages");
    if (res.ok) {
      const languages = await res.json();
      const switchers = document.querySelectorAll(".ui-lang-switcher");
      switchers.forEach((select) => {
        select.innerHTML = "";
        languages.forEach((l) => {
          const option = document.createElement("option");
          option.value = l.code;
          option.textContent = `${l.flag ? l.flag + " " : ""}${l.name}`;
          if (l.code === window.i18n.currentLang) {
            option.selected = true;
          }
          select.appendChild(option);
        });

        select.addEventListener("change", async function (e) {
          const selectedLang = e.target.value;
          await setLanguage(selectedLang);
        });
      });
    }
  } catch (err) {
    console.error("Failed to fetch available languages:", err);
  }

  // Initial translation loading
  await loadAndApplyLanguage(window.i18n.currentLang);
});

async function setLanguage(lang) {
  window.i18n.currentLang = lang;
  localStorage.setItem("ui_lang", lang);
  history.pushState(null, "", "/?lang=" + lang);

  // Sync any other switchers on the page
  document.querySelectorAll(".ui-lang-switcher").forEach((select) => {
    select.value = lang;
  });

  await loadAndApplyLanguage(lang);
}

async function loadAndApplyLanguage(lang) {
  try {
    const res = await fetch(`/i18n/${lang}.json?t=${Date.now()}`);
    if (res.ok) {
      window.i18n.dictionary = await res.json();
      window.i18n.applyTranslations();
      window.dispatchEvent(
        new CustomEvent("languageChanged", { detail: { lang: lang } }),
      );
    }
  } catch (err) {
    console.error(`Failed to load translation file for ${lang}:`, err);
  }
}
