/** MooshieUIplus TAG zh-TW overlay. Does not change canonical English tags. */
import dictionary from "./tags.zh-TW.json";
type Entry = { n: string; a?: string[]; c?: number };
const translations = dictionary.translations as Record<string, string[]>;
const HAN = /[\u3400-\u9fff]/u;
const GENERIC = new Set(["動作", "动作", "頭髮", "头发", "服裝", "服装", "背景", "場景", "场景", "表情", "構圖", "构图", "品質", "品质"]);
export function withChineseTagAliases<T extends Entry>(rows: T[]): T[] {
  return rows.map((row) => {
    const labels = translations[row.n];
    if (!labels?.length) return row;
    const aliases = [...new Set([...(row.a ?? []), ...labels])];
    return { ...row, a: aliases };
  });
}
export function chineseLabelsForTag(row: Entry, query = ""): string[] {
  const labels = [...new Set((row.a ?? []).filter((text) => HAN.test(text) && text.length <= 64 && !text.includes("_") && !GENERIC.has(text)))];
  if (!labels.length) return [];
  if (row.c === 4) {
    const withWork = [...labels].reverse().find((label) => /（[^）]+）/u.test(label));
    return [withWork ?? labels[labels.length - 1]];
  }
  const q = query.trim().replace(/\s+/g, "_");
  if (HAN.test(q)) {
    const starts = labels.filter((label) => label.startsWith(q));
    if (starts.length) return starts.slice(0, 2);
  }
  return labels.slice(-2).reverse();
}
