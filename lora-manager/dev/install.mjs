/** Install LoRA Info Management as an independently loaded H1 tab.
 * Operates only on a source tree with the exact installed MooshieUI version.
 * Existing LoRA selector/other add-ons are intentionally left alone.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const here = path.dirname(fileURLToPath(import.meta.url));
const source = path.resolve(process.argv[2] ?? path.join(here, "../../source"));
const packageFile = path.join(source, "package.json");
if (!fs.existsSync(packageFile)) throw Error("Missing MooshieUI source");
const version = JSON.parse(fs.readFileSync(packageFile, "utf8")).version;
if (!["2.3.45", "2.3.49"].includes(version)) throw Error("LoRA 資訊管理未適配此版原始碼，拒絕跨版覆蓋：" + version);

const bottomPath = path.join(source, "src/lib/components/generation/BottomPanel.svelte");
const modPath = path.join(source, "src-tauri/src/commands/mod.rs");
const libPath = path.join(source, "src-tauri/src/lib.rs");
const webPath = path.join(source, "src-tauri/src/webserver.rs");
const addonPath = path.join(source, "src/lib/addons/lora-browser");
const rustTarget = path.join(source, "src-tauri/src/commands/lora_info.rs");

function replaceOnce(text, oldText, newText, label) {
  if (!text.includes(oldText)) throw Error("MooshieUI 2.3.45 anchor changed: " + label);
  return text.replace(oldText, newText);
}
function addAfter(text, target, addition, marker) {
  if (text.includes(marker)) return text;
  return replaceOnce(text, target, target + addition, marker);
}
function addBefore(text, target, addition, marker) {
  if (text.includes(marker)) return text;
  return replaceOnce(text, target, addition + target, marker);
}

let bottom = fs.readFileSync(bottomPath, "utf8");
let mod = fs.readFileSync(modPath, "utf8");
let lib = fs.readFileSync(libPath, "utf8");
let web = fs.readFileSync(webPath, "utf8");

bottom = addAfter(bottom,
  '  import PromptGeneratorPage from "../../addons/prompt-generator/PromptGeneratorPage.svelte";',
  '\n  import LoraInfoPanel from "../../addons/lora-browser/LoraInfoPanel.svelte";',
  'import LoraInfoPanel from ');
if (!bottom.includes('| "lora_info";')) {
  bottom = replaceOnce(bottom, ' | "prompt_generator";', ' | "prompt_generator" | "lora_info";', "TabId");
}
if (!bottom.includes('"prompt_generator", "lora_info"]')) {
  bottom = replaceOnce(bottom, '"notes", "prompt_generator"];',
    '"notes", "prompt_generator", "lora_info"];', "allTabs");
}
bottom = addAfter(bottom, '    prompt_generator: "bottom_panel.tab.notes",',
  '\n    lora_info: "bottom_panel.tab.notes",', 'lora_info: "bottom_panel.tab.notes"');
if (!bottom.includes('tab === "lora_info" ? "LoRA 資訊管理"')) {
  bottom = replaceOnce(bottom,
    '{tab === "prompt_generator" ? "Prompt Generator" : locale.t(tabLabelKey(tab))}',
    '{tab === "prompt_generator" ? "Prompt Generator" : tab === "lora_info" ? "LoRA 資訊管理" : locale.t(tabLabelKey(tab))}',
    "tab label");
}
if (!bottom.includes('{:else if activeTab === "lora_info"}')) {
  bottom = addAfter(bottom,
    '      <PromptGeneratorPage />',
    '\n    {:else if activeTab === "lora_info"}\n      <LoraInfoPanel />',
    '{:else if activeTab === "lora_info"}');
}

mod = addAfter(mod, "pub mod api;", "\npub mod lora_info;", "pub mod lora_info;");
lib = addAfter(lib, "            commands::picture_generator::picture_generator_action,",
  "\n            commands::lora_info::lora_info_action,", "commands::lora_info::lora_info_action");
web = addAfter(web, '    "save_model_sidecar_thumbnail",',
  '\n    "lora_info_action",', '"lora_info_action",');
if (!web.includes('"lora_info_action" => {')) {
  web = addBefore(web, '        "save_model_sidecar_thumbnail" => {',
`        "lora_info_action" => {
            let action = args["action"].as_str().ok_or("Missing action")?;
            let filename = args["filename"].as_str().ok_or("Missing filename")?;
            let entry = args.get("entry").cloned();
            let image_bytes = if let Some(items) = args.get("imageBytes").or_else(|| args.get("image_bytes")).and_then(|v| v.as_array()) {
                if items.len() > 15 * 1024 * 1024 { return Err("封面圖片過大".into()); }
                let mut bytes = Vec::with_capacity(items.len());
                for v in items {
                    let n = v.as_u64().filter(|n| *n <= 255).ok_or("Invalid image bytes")?;
                    bytes.push(n as u8);
                }
                Some(bytes)
            } else { None };
            let gallery_filename = args.get("galleryFilename").or_else(|| args.get("gallery_filename")).and_then(|v| v.as_str());
            let gallery_dir = if gallery_filename.is_some() {
                Some(user_gallery_dir(username).ok_or("Cannot find gallery directory")?)
            } else { None };
            commands::lora_info::lora_info_action_inner(
                state.as_ref(), action, filename, entry, image_bytes,
                gallery_filename, gallery_dir.as_deref()
            ).await
        }
`,
    '"lora_info_action" => {');
}

// Preflight finished. All writes are confined to the explicitly selected matching source.
fs.writeFileSync(bottomPath, bottom);
fs.writeFileSync(modPath, mod);
fs.writeFileSync(libPath, lib);
fs.writeFileSync(webPath, web);
fs.mkdirSync(addonPath, { recursive: true });
fs.copyFileSync(path.join(here, "LoraInfoPanel.svelte"), path.join(addonPath, "LoraInfoPanel.svelte"));
fs.copyFileSync(path.join(here, "lora_info.rs"), rustTarget);
fs.copyFileSync(path.join(here, "version.json"), path.join(addonPath, "version.json"));
execFileSync(process.execPath, [path.join(here, "install-browser-v2.mjs"), source], { stdio: "inherit" });
console.log("LoRA Info Management and Browser V2 installed into MooshieUI " + version + " source. User data and weights unchanged.");
