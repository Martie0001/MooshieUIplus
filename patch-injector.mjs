/** Apply unified module patches by unique code anchors, not source-version context. */
import fs from "node:fs";
import path from "node:path";

export function injectPatch(source, patchFile) {
  const lines = fs.readFileSync(patchFile, "utf8").replaceAll("\r\n", "\n").split("\n");
  const updates = new Map();
  let file = null;
  let hunks = [];
  function commitFile() {
    if (!file) return;
    const target = path.resolve(source, file);
    if (!target.startsWith(path.resolve(source) + path.sep)) throw new Error("Unsafe patch path: " + file);
    const original = fs.readFileSync(target, "utf8");
    const eol = original.includes("\r\n") ? "\r\n" : "\n";
    let text = original.replaceAll("\r\n", "\n");
    for (const hunk of hunks) {
      const oldLines = hunk.filter(x => x[0] !== "+").map(x => x.slice(1));
      const newLines = hunk.filter(x => x[0] !== "-").map(x => x.slice(1));
      const oldText = oldLines.join("\n");
      const newText = newLines.join("\n");
      if (text.includes(newText)) continue; // Already contains this specific change.
      const matches = [];
      let index = -1;
      while ((index = text.indexOf(oldText, index + 1)) >= 0) matches.push(index);
      if (matches.length !== 1) throw new Error(`Cannot safely locate a unique injection anchor in ${file}: ${oldLines.find(Boolean)?.slice(0, 90)} (matches=${matches.length})`);
      text = text.slice(0, matches[0]) + newText + text.slice(matches[0] + oldText.length);
    }
    if (text !== original.replaceAll("\r\n", "\n")) updates.set(target, text.replaceAll("\n", eol));
  }
  for (const line of lines) {
    if (line.startsWith("diff --git ")) { commitFile(); file = null; hunks = []; continue; }
    if (line.startsWith("+++ b/")) { file = line.slice(6); continue; }
    if (line.startsWith("@@ ")) { if (!file) throw new Error("Hunk without target"); hunks.push([]); continue; }
    if (hunks.length && /^[ +\-]/.test(line)) hunks[hunks.length - 1].push(line);
    if (line.startsWith("\\ No newline")) continue;
  }
  commitFile();
  // Check every affected file and anchor before writing any file.
  for (const [target, contents] of updates) fs.writeFileSync(target, contents, "utf8");
  return updates.size;
}
