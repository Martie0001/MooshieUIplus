/** LoRA type labels are metadata. Folder names are separate selectors and never rename weights. */
import config from "./lora-categories.json";
import type { LoraCivitaiInfo } from "../../utils/api.js";

export type LoraType = "style" | "character" | "effect" | "other";
export type LoraFilter = "all" | LoraType;
export type LoraGame = string;

const configured = config.types as Record<string, LoraType[]>;
const allowed = new Set<LoraType>(["style", "character", "effect", "other"]);

function folderOf(filename: string): string {
  const parts = filename.replace(/\\/g, "/").split("/");
  parts.pop();
  const parent = parts.at(-1);
  return parent && parent !== "Anima" ? parent : "other";
}

export function availableLoraGames(filenames: string[]): LoraGame[] {
  return [...new Set(filenames.map(folderOf).filter((folder) => folder !== "other"))]
    .sort((a, b) => a.localeCompare(b));
}

export function classifyLora(
  filename: string,
  overrides: Record<string, LoraType[]> = {},
  info?: LoraCivitaiInfo | null,
): { types: LoraType[]; game: LoraGame; inferred: boolean } {
  const normalized = filename.replace(/\\/g, "/");
  const basename = normalized.split("/").at(-1) ?? normalized;
  const game = folderOf(filename);

  // User-provided types are authoritative; metadata tags have secondary priority.
  const override = overrides[normalized] ?? overrides[basename] ??
    configured[normalized] ?? configured[basename];
  if (override?.some((type) => allowed.has(type))) {
    return { types: [...new Set(override.filter((type) => allowed.has(type)))], game, inferred: false };
  }

  const declared = (info?.modelspec_tags ?? "").split(/[;,|]/)
    .map((tag) => tag.trim().toLowerCase());
  const metadataTypes = [...new Set(declared.filter((tag): tag is LoraType => allowed.has(tag as LoraType)))];
  if (metadataTypes.length) return { types: metadataTypes, game, inferred: false };

  // Only category-named folders provide a reliable fallback. Work/game folder
  // names are not evidence of a character LoRA on another user's machine.
  const folder = game.toLowerCase();
  const guessed: LoraType = folder === "style" || game === "風格"
    ? "style"
    : folder === "character" || folder === "characters" || game === "角色"
      ? "character"
      : folder === "effect" || folder === "effects" || game === "效果"
        ? "effect" : "other";
  return { types: [guessed], game, inferred: true };
}

export function matchesLora(
  filename: string,
  tab: LoraFilter | "",
  game: LoraGame | "",
  overrides: Record<string, LoraType[]> = {},
  info?: LoraCivitaiInfo | null,
): boolean {
  if (!tab || !game) return false;
  const result = classifyLora(filename, overrides, info);
  return (game === "all" || result.game === game)
    && (tab === "all" || result.types.includes(tab));
}
