/** Apply the LoRA Browser V2 classification and lazy-card UI to an existing MooshieUI source tree.
 * The addon is source-level (not a hot plugin). Does not touch weights or user data.
 * Intended to run after the existing lora-browser base and independent LoRA Info module are present.
 */
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const source = path.resolve(process.argv[2] ?? path.join(here, "../../source"));
const packageFile = path.join(source, "package.json");
const galleryPath = path.join(source, "src/lib/components/generation/LoraGallery.svelte");
const addonPath = path.join(source, "src/lib/addons/lora-browser");
const patchFile = path.join(here, "lora-browser-v2.patch");

if (!fs.existsSync(packageFile) || !fs.existsSync(galleryPath)) {
  throw new Error("MooshieUI source or LoRA gallery missing; no changes made.");
}
const version = JSON.parse(fs.readFileSync(packageFile, "utf8")).version;
const original = fs.readFileSync(galleryPath, "utf8");
if (!original.includes("import LoraFilterBar") || !original.includes("import LoraExternalSearch")) {
  throw new Error("Cannot find existing LoRA Browser injection anchors; no changes made.");
}
for (const filename of ["LoraFilterBar.svelte", "LoraExternalSearch.svelte", "loraCategories.ts", "lora-categories.json"]) {
  if (!fs.existsSync(path.join(here, filename))) {
    throw new Error("Missing LoRA browser component: " + filename);
  }
}
const isAlreadyV2 = original.includes("const pagedLoras =") && original.includes("!loadReady");
if (!isAlreadyV2) {
  // Check before changing anything; a different upstream layout must not be overwritten.
  execFileSync("git", ["apply", "--check", patchFile], { cwd: source, stdio: "pipe" });
  execFileSync("git", ["apply", patchFile], { cwd: source, stdio: "pipe" });
}
fs.mkdirSync(addonPath, { recursive: true });
for (const filename of ["LoraFilterBar.svelte", "LoraExternalSearch.svelte", "loraCategories.ts", "lora-categories.json"]) {
  fs.copyFileSync(path.join(here, filename), path.join(addonPath, filename));
}
console.log("LoRA Browser V2 applied to MooshieUI " + version + ". User data and weights unchanged.");
