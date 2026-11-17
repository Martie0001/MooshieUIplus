import fs from "node:fs";
import path from "node:path";
import { injectPatch } from "../../patch-injector.mjs";
import { fileURLToPath } from "node:url";

const folder = path.dirname(fileURLToPath(import.meta.url));
const source = path.resolve(process.argv[2] ?? path.join(folder,"../../source"));
const ui = path.join(source,"src/lib/addons/prompt-generator/PromptGeneratorPage.svelte");
const rust = path.join(source,"src-tauri/src/commands/picture_generator.rs");
const bottom = path.join(source,"src/lib/components/generation/BottomPanel.svelte");
const version = JSON.parse(fs.readFileSync(path.join(source, "package.json"), "utf8")).version;
const patch = path.join(folder, ["2.3.43", "2.3.44", "2.3.45"].includes(version) ? "integration-v2.3.43.patch" : "integration.patch");
if(!["2.3.34", "2.3.43", "2.3.44", "2.3.45", "2.3.49"].includes(version)) throw Error("Prompt Generator 尚未適配 MooshieUI " + version);
if(!fs.existsSync(bottom) || !fs.existsSync(patch)) throw Error("缺少 MooshieUI 原始碼或 Prompt Generator 安裝檔");
const existing = fs.readFileSync(bottom,"utf8").includes("PromptGeneratorPage");
if(!existing) {
  const changed = injectPatch(source, patch);
  console.log("Prompt Generator inserted into " + changed + " source files");
}
fs.mkdirSync(path.dirname(ui),{recursive:true});
fs.copyFileSync(path.join(folder,"PromptGeneratorPage.svelte"),ui);
fs.copyFileSync(path.join(folder,"picture_generator.rs"),rust);
fs.copyFileSync(path.join(folder,"version.json"),path.join(path.dirname(ui),"version.json"));
console.log("Prompt Generator integration installed. Service is configurable via MOOSHIEUI_PROMPT_SERVICE or MooshieUI app data.");
