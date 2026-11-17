/** Type tags and folder selection are independent: a single LoRA can belong to several types. */
import config from "./lora-categories.json";
import type { LoraCivitaiInfo } from "../../utils/api.js";

export type LoraType = "style" | "character" | "clothing" | "effect" | "other";
export type LoraFilter = "all" | LoraType;
export type LoraGame = string;
export const LORA_ROOT_FOLDER = "LoRA（主目錄）";

const configured = config.types as Record<string, LoraType[]>;
const allowed = new Set<LoraType>(["style", "character", "clothing", "effect", "other"]);
const characterWorks = new Set([
  "genshin_impact", "zenless_zone_zero", "blue_archive",
  "arknights_endfield", "limbus_company", "mahou shoujo no majo saiban",
  "granblue_fantasy", "kancolle",
]);

function folderOf(filename: string): string {
  const parts = filename.replace(/\\/g, "/").split("/");
  parts.pop();
  const parent = parts.at(-1);
  // Files directly below the LoRA root (or the Anima root) are a virtual folder.
  return parent && parent.toLowerCase() !== "anima" ? parent : LORA_ROOT_FOLDER;
}

export function availableLoraGames(filenames: string[]): LoraGame[] {
  return [...new Set(filenames.map(folderOf))]
    .sort((a, b) => a.localeCompare(b));
}

export function classifyLora(
  filename: string,
  overrides: Record<string, LoraType[]> = {},
  info?: Pick<LoraCivitaiInfo, "modelspec_tags"> | null,
): { types: LoraType[]; game: LoraGame; inferred: boolean } {
  const normalized = filename.replace(/\\/g, "/");
  const basename = normalized.split("/").at(-1) ?? normalized;
  const game = folderOf(filename);

  // Saved user decisions always win, including multi-type combinations.
  const override = overrides[normalized] ?? overrides[basename] ??
    configured[normalized] ?? configured[basename];
  if (override?.some((type) => allowed.has(type))) {
    return { types: [...new Set(override.filter((type) => allowed.has(type)))], game, inferred: false };
  }

  // Only explicit type-like ModelSpec tags count as verified classification.
  const aliases: Record<string, LoraType> = {
    character: "character", characters: "character",
    style: "style", styles: "style",
    clothing: "clothing", clothes: "clothing", costume: "clothing", outfit: "clothing",
    effect: "effect", effects: "effect", concept: "effect",
    poses: "effect", pose: "effect", action: "effect",
  };
  const declared = (info?.modelspec_tags ?? "").split(/[;,|]/)
    .map((tag) => tag.trim().toLowerCase());
  const metadataTypes = [...new Set(declared.map((tag) => aliases[tag]).filter((type): type is LoraType => !!type))];
  if (metadataTypes.length) return { types: metadataTypes, game, inferred: false };

  // Folder conventions are only fallbacks. Never treat a guessed type as metadata.
  const folder = game.toLowerCase();
  const guessed: LoraType = folder === "style" || game === "風格"
    ? "style"
    : folder === "clothing" || folder === "clothes" || folder === "outfit" || game === "服裝"
      ? "clothing"
      : folder === "character" || folder === "characters" || game === "角色" || characterWorks.has(folder)
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
  info?: Pick<LoraCivitaiInfo, "modelspec_tags"> | null,
): boolean {
  if (!tab || !game) return false;
  const result = classifyLora(filename, overrides, info);
  return (game === "all" || result.game === game)
    && (tab === "all" || result.types.includes(tab));
}
