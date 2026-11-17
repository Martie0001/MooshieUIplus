/** Install Creative Tools V1 into an exact matching MooshieUI source tree.
 * The official desktop executable and persistent module_data are not changed.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { injectPatch } from "../../patch-injector.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const source = path.resolve(process.argv[2] ?? path.join(here, "../../source"));
const generationPage = path.join(source, "src/lib/components/generation/GenerationPage.svelte");
const packageFile = path.join(source, "package.json");
if (!fs.existsSync(packageFile) || !fs.existsSync(generationPage)) {
  throw new Error("MooshieUI source tree not found: " + source);
}
const version = JSON.parse(fs.readFileSync(packageFile, "utf8")).version;
if (!["2.3.34", "2.3.43", "2.3.44", "2.3.45", "2.3.49"].includes(version)) throw new Error("Creative Tools has no verified integration for MooshieUI " + version);
const installedPanel = path.join(source, "src/lib/components/generation/CreativeToolsPanel.svelte");
const installedOutpaint = path.join(source, "src/lib/utils/creativeOutpaint.ts");
const installedReference = path.join(source, "src/lib/utils/creativeReference.ts");
const patch = path.join(here, "creative-v1.patch");
const upgradePatch = path.join(here, "creative-v08-upgrade.patch");
const posePatch = path.join(here, "creative-v22-upgrade.patch");
const poseDetectPatch = path.join(here, "creative-v22-detect.patch");
const sourceText = fs.readFileSync(generationPage, "utf8");
if (sourceText.includes('import CreativeToolsPanel from "./CreativeToolsPanel.svelte";')) {
  if (!sourceText.includes('onOutpaint={creativeToOutpaint}')) {
    throw new Error("Creative Tools has an incomplete or incompatible integration.");
  }
  if (!sourceText.includes("onReferenceApply={creativeToReference}")) {
    console.log("Upgrading Creative Tools V0.2 reference workflow...");
    injectPatch(source, upgradePatch);
  } else {
    console.log("Creative Tools UI already integrated.");
  }
} else {
  console.log("Injecting Creative Tools UI...");
  injectPatch(source, ["2.3.43", "2.3.44", "2.3.45"].includes(version) ? path.join(here, "creative-v2.3.43.patch") : patch);
}
// Existing v2.3.43 installations also need the historical gallery and
// mask-specific outpaint update; a fresh installation already has these changes.
if (["2.3.43", "2.3.44", "2.3.45"].includes(version) &&
    !fs.readFileSync(path.join(source, "src/App.svelte"), "utf8").includes("creativeHandoffSequence")) {
  console.log("Upgrading Creative Tools v0.4.3 gallery / outpaint integration...");
  injectPatch(source, path.join(here, "creative-v2.3.43-ux.patch"));
}
if (!fs.readFileSync(generationPage, "utf8").includes("onPoseApply={creativeToPose}")) {
  console.log("Upgrading Creative Tools V0.3.1 pose workflow...");
  injectPatch(source, posePatch);
}
if (["2.3.43", "2.3.44", "2.3.45"].includes(version)) {
  console.log("Ensuring Creative Tools 11 target dimensions...");
  injectPatch(source, path.join(here, "creative-v11-dimensions.patch"));
}
console.log("Ensuring Creative Tools 22 Anima pose route...");
injectPatch(source, path.join(here, "creative-v22-anima.patch"));
const controlnetBackend = path.join(source, "src-tauri/src/templates/controlnet.rs");
if (!fs.readFileSync(controlnetBackend, "utf8").includes('if preprocessor == "OpenposePreprocessor" {')) {
  console.log("Upgrading Creative Tools V0.4 pose detection history bridge...");
  injectPatch(source, poseDetectPatch);
}
// Extend the existing generation-page tab type without touching native generation modes.
const pageForComic = fs.readFileSync(generationPage, "utf8");
const oldComicType = 'type CreativeTool = "reference" | "outpaint" | "pose" | "postprocess";';
if (pageForComic.includes(oldComicType)) {
  fs.writeFileSync(generationPage, pageForComic.replace(oldComicType,
    'type CreativeTool = "reference" | "outpaint" | "pose" | "postprocess" | "comic";'));
} else if (!pageForComic.includes('type CreativeTool = "reference" | "outpaint" | "pose" | "postprocess" | "comic";')) {
  throw new Error("Cannot locate CreativeTool type in generation page; integration aborted.");
}
for (const [src, dst] of [
  ["CreativeToolsPanel.svelte", installedPanel],
  ["CreativeComicEditor.svelte", path.join(source, "src/lib/components/generation/CreativeComicEditor.svelte")],
  ["creativeOutpaint.ts", installedOutpaint],
  ["creativeReference.ts", installedReference],
  ["CreativePoseEditor.svelte", path.join(source, "src/lib/components/generation/CreativePoseEditor.svelte")],
  ["creativePose.ts", path.join(source, "src/lib/utils/creativePose.ts")],
]) {
  const content = fs.readFileSync(path.join(here, src));
  fs.writeFileSync(dst, content);
}
console.log("Creative Tools V1 source install complete (no EXE deployment).");
