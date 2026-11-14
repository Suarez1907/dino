import catalog from "@shared/catalog.json";
import dinosaurs from "@shared/dinosaurs.json";
import sites from "@shared/sites.json";
import strings from "@shared/strings.json";

export { catalog, dinosaurs, sites, strings };

export function t(lang, key, extra = {}) {
  const entry = strings[key];
  let value = entry ? entry[lang] || entry.tr : key;
  for (const [name, replacement] of Object.entries(extra)) {
    value = value.replaceAll(`{${name}}`, String(replacement));
  }
  return value;
}

export function pick(lang, entry) {
  if (!entry) return "";
  if (typeof entry === "string") return entry;
  return entry[lang] || entry.tr || "";
}

export function dinoById(id) {
  return dinosaurs.find((dino) => dino.id === id);
}

export function siteById(id) {
  return sites.find((site) => site.id === id);
}
