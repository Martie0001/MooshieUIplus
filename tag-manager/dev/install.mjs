/** Install/update this standalone source-level add-on against MooshieUI. Idempotent. */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
const here = path.dirname(fileURLToPath(import.meta.url));
const source = path.resolve(process.argv[2] ?? path.join(here, "../../source"));
const addon = path.join(source, "src/lib/addons/tag-zh-tw");
if (!fs.existsSync(path.join(source, "src/lib/stores/autocomplete.svelte.ts"))) throw new Error("MooshieUI source not found: " + source);
// Prefer an explicitly configured personal dictionary; otherwise use the
// bundled public/default translations. No machine-specific paths are assumed.
const dictionaryPath = process.env.MOOSHIEUI_TAG_DICTIONARY || path.join(here, "tags.zh-TW.json");
if (!fs.existsSync(dictionaryPath)) throw new Error("Missing TAG dictionary: " + dictionaryPath);
fs.mkdirSync(addon, { recursive: true });
fs.copyFileSync(path.join(here, "tagTranslations.ts"), path.join(addon, "tagTranslations.ts"));
fs.copyFileSync(dictionaryPath, path.join(addon, "tags.zh-TW.json"));
function patch(relative, before, after, id) {
  const file = path.join(source, relative);
  const old = fs.readFileSync(file, "utf8");
  const eol = old.includes("\r\n") ? "\r\n" : "\n";
  const oldText = before.replaceAll("\n", eol);
  const newText = after.replaceAll("\n", eol);
  if (id === "tag import" && old.includes('import { withChineseTagAliases } from "../addons/tag-zh-tw/tagTranslations.js";')) { console.log(id + ": already installed"); return; }
  if (id === "tag bilingual display" && old.includes("chineseLabelsForTag(tag).length > 0")) { console.log(id + ": already installed"); return; }
  if (old.includes(newText)) { console.log(id + ": already installed"); return; }
  if (!old.includes(oldText)) throw new Error(id + ": unsupported upstream change, no files written to " + file);
  fs.writeFileSync(file, old.replace(oldText, newText), "utf8");
  console.log(id + ": applied");
}
patch("src/lib/stores/autocomplete.svelte.ts",
  'import builtinTags from "../assets/danbooru-tags.json";',
  'import builtinTags from "../assets/danbooru-tags.json";\nimport { withChineseTagAliases } from "../addons/tag-zh-tw/tagTranslations.js";',
  "tag import");
patch("src/lib/stores/autocomplete.svelte.ts",
  '    this.tags = tags;\n    this.rebuildSearchIndex(tags);',
  '    this.tags = withChineseTagAliases(tags);\n    this.rebuildSearchIndex(this.tags);',
  "tag search and alias merge");
patch("src/lib/components/generation/PromptTextarea.svelte",
  '  import { autocomplete, type TagEntry } from "../../stores/autocomplete.svelte.js";',
  '  import { autocomplete, type TagEntry } from "../../stores/autocomplete.svelte.js";\n  import { chineseLabelsForTag } from "../../addons/tag-zh-tw/tagTranslations.js";',
  "tag UI import");
patch("src/lib/components/generation/PromptTextarea.svelte",
  'class="fixed z-[200] w-80 max-h-60 overflow-y-auto',
  'class="fixed z-[200] w-[380px] max-h-60 overflow-y-auto',
  "tag UI width");
patch("src/lib/components/generation/PromptTextarea.svelte",
  '            <span class={CATEGORY_COLORS[tag.c] ?? "text-neutral-300"}>\n              {formatTagForDisplay(tag.n)}\n            </span>',
  '            <span class="min-w-0 flex-1 flex flex-col">\n              <span class={CATEGORY_COLORS[tag.c] ?? "text-neutral-300"}>{formatTagForDisplay(tag.n)}</span>\n              {#if chineseLabelsForTag(tag).length > 0}\n                <span class="text-[11px] text-neutral-400 truncate" title={chineseLabelsForTag(tag).join(" / ")}>{chineseLabelsForTag(tag).join(" · ")}</span>\n              {/if}\n            </span>',
  "tag bilingual display");
patch("src/lib/components/generation/PromptTextarea.svelte",
  "const DROPDOWN_WIDTH = 320; // w-80",
  "const DROPDOWN_WIDTH = 380; // bilingual rows",
  "tag dropdown placement");
// Keep the installed bilingual UI fixes when rebuilding from the shared source.
const promptFile = path.join(source, "src/lib/components/generation/PromptTextarea.svelte");
const promptOriginal = fs.readFileSync(promptFile, "utf8");
const promptEol = promptOriginal.includes("\r\n") ? "\r\n" : "\n";
let promptText = promptOriginal.replaceAll("\r\n", "\n");
const fixes = [
  ["showSuggestions = suggestions.length > 0;", "showSuggestions = suggestions.length > 0 || categoryFilter !== null;"],
  ['class="rounded-full border px-2 py-0.5 text-[10px] transition-colors cursor-pointer', 'class="rounded-full border px-2 py-0.5 text-xs transition-colors cursor-pointer'],
  ['class="text-[11px] text-neutral-400 truncate" title={chineseLabelsForTag(tag).join(" / ")}', 'class="text-sm text-neutral-300/85 truncate" title={chineseLabelsForTag(tag).join(" / ")}'],
  ['    // Autocomplete navigation\n    if (showSuggestions) {',
   '    // Autocomplete navigation\n    if (showSuggestions && e.key === "Escape") {\n      e.preventDefault();\n      showSuggestions = false;\n      return;\n    }\n    if (showSuggestions && suggestions.length > 0) {'],
  ['      {#each suggestions as tag, i (tag.n)}',
   '      {#if suggestions.length === 0}\n        <div class="px-3 py-3 text-sm text-neutral-400">此分類無符合結果</div>\n      {/if}\n      {#each suggestions as tag, i (tag.n)}'],
];
for (const [before, after] of fixes) {
  if (promptText.includes(after)) continue;
  if (!promptText.includes(before)) throw new Error("TAG UI compatibility mismatch: " + before.slice(0, 48));
  promptText = promptText.replace(before, after);
}
if (promptText !== promptOriginal.replaceAll("\r\n", "\n")) {
  fs.writeFileSync(promptFile, promptText.replaceAll("\n", promptEol), "utf8");
}
console.log("TAG zh-TW module installed on source " + source);
