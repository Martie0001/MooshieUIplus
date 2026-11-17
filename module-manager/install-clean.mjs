/**
 * Integrate all MooshieUIplus add-ons into a pristine MooshieUI 2.3.49 source.
 * The integration patch is generated against the upstream 2.3.49 Git baseline.
 * This script never touches installed EXEs, models, or user profiles.
 */
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const bundle = path.resolve(here, "..");
const source = path.resolve(process.argv[2] ?? "");
if (!process.argv[2]) throw new Error("Usage: node module-manager/install-clean.mjs <MooshieUI 2.3.49 source>");
const packageFile = path.join(source, "package.json");
if (!fs.existsSync(packageFile)) throw new Error("MooshieUI source package.json not found");
const version = JSON.parse(fs.readFileSync(packageFile, "utf8")).version;
if (version !== "2.3.49") throw new Error("Clean integration supports MooshieUI 2.3.49 only, found " + version);

const gallery = fs.readFileSync(path.join(source, "src/lib/components/generation/LoraGallery.svelte"), "utf8");
const bottom = fs.readFileSync(path.join(source, "src/lib/components/generation/BottomPanel.svelte"), "utf8");
const page = fs.readFileSync(path.join(source, "src/lib/components/generation/GenerationPage.svelte"), "utf8");
const integrated = gallery.includes('import LoraFilterBar') &&
  bottom.includes('import PromptGeneratorPage') && page.includes('import CreativeToolsPanel');
const modified = gallery.includes('import LoraFilterBar') ||
  bottom.includes('import PromptGeneratorPage') || page.includes('import CreativeToolsPanel');

if (modified && !integrated) {
  throw new Error("Partial add-on installation detected. Restore a pristine upstream 2.3.49 source before proceeding.");
}
if (!integrated) {
  const patch = path.join(here, "integrated-2.3.49.patch");
  // Check the entire patch before changing a single file.
  execFileSync("git", ["apply", "--check", patch], { cwd: source, stdio: "inherit" });
  execFileSync("git", ["apply", patch], { cwd: source, stdio: "inherit" });
}
for (const [folder, label] of [
  ["tag-manager", "TAG"],
  ["prompt-generator", "Prompt Generator"],
  ["lora-manager", "LoRA"],
  ["creative-tools", "Creative Tools"],
]) {
  const installer = path.join(bundle, folder, "dev", "install.mjs");
  execFileSync(process.execPath, [installer, source], { stdio: "inherit" });
  console.log(label + " installed");
}
console.log("MooshieUIplus source integration complete for 2.3.49. No EXE deployed.");
