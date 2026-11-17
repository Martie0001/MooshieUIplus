/** Native workflow handoff for Creative Tools 08. No model or node is installed here. */
export type ReferenceKind = "character" | "outfit" | "style";
export const REFERENCE_KINDS: ReferenceKind[] = ["character", "outfit", "style"];
export const REFERENCE_LABELS: Record<ReferenceKind, string> = {
  character: "角色外觀", outfit: "服裝樣式", style: "畫風參考",
};
export interface ReferenceSlotSetting {
  enabled: boolean;
  strength: number; // 10-100. Qwen uses semantic emphasis, not numeric conditioning.
}
export type ReferenceSettings = Record<ReferenceKind, ReferenceSlotSetting>;
export type ReferenceImageNames = Record<ReferenceKind, string | null>;
export type ReferenceRoute = "qwen_edit" | "anima_character" | "anima_style" | "sdxl_adapter";
export interface ReferencePlan {
  route: ReferenceRoute;
  ordered: ReferenceKind[];
  instructions: string;
  nativeStrength?: number;
}

/** Image numbering must follow backend's filtered reference order, not UI slot number. */
export function planReferenceHandoff(
  modelFamily: string,
  images: ReferenceImageNames,
  settings: ReferenceSettings,
): ReferencePlan {
  const selected = REFERENCE_KINDS.filter(kind => {
    const config = settings[kind];
    if (!config.enabled) return false;
    if (!Number.isInteger(config.strength) || config.strength < 10 || config.strength > 100) {
      throw new Error(`「${REFERENCE_LABELS[kind]}」強度必須介於 10–100%`);
    }
    if (!images[kind]) throw new Error(`請先為「${REFERENCE_LABELS[kind]}」選擇圖片`);
    return true;
  });
  if (!selected.length) throw new Error("至少開啟並上傳一種參考圖片");
  const only = selected[0];

  if (modelFamily === "qwen_edit_plus" || modelFamily === "qwen_edit") {
    if (modelFamily === "qwen_edit" && selected.length > 1) {
      throw new Error("目前 Qwen Image Edit 僅支援一張參考圖；同時使用角色＋服裝請選擇 Qwen Image Edit Plus");
    }
    const instructions = selected.map((kind, i) => {
      const strength = settings[kind].strength;
      const emphasis = strength >= 75 ? "Preserve closely" : strength >= 40 ? "Preserve faithfully" : "Use as a light guide";
      if (kind === "character")
        return `Reference image ${i + 1} is ONLY the character identity reference. ${emphasis} the face, hair and recognizable character features; do not copy its outfit or art style unless separately requested.`;
      if (kind === "outfit")
        return `Reference image ${i + 1} is ONLY the clothing reference. ${emphasis} its garment shapes, layers and details; do not copy the person's face or the image's art style.`;
      return `Reference image ${i + 1} is ONLY the art style reference. ${emphasis} the rendering, linework, palette and texture; do not copy its character identity or clothing.`;
    }).join("\n");
    return { route: "qwen_edit", ordered: selected, instructions };
  }

  if (modelFamily === "anima") {
    if (selected.length > 1) {
      throw new Error("Anima 的角色參考與風格轉換使用不同原生流程，無法同時獨立套用；角色＋服裝雙參考請選 Qwen Image Edit Plus");
    }
    if (only === "outfit") throw new Error("Anima 目前沒有可獨立鎖定服裝的參考工作流");
    return {
      route: only === "character" ? "anima_character" : "anima_style",
      ordered: selected, instructions: "",
      nativeStrength: settings[only].strength / 100,
    };
  }

  if (["sd15", "sdxl", "illustrious", "pony"].includes(modelFamily)) {
    if (selected.length > 1) throw new Error("此模型的 IP-Adapter 原生流程目前只接受一張參考圖，不能分離角色、服裝、風格");
    if (only === "outfit") throw new Error("單張 IP-Adapter 無法可靠地獨立保留服裝，請選擇角色或風格參考");
    return {
      route: "sdxl_adapter",
      ordered: selected, instructions: "",
      nativeStrength: settings[only].strength / 100,
    };
  }

  throw new Error("目前選擇的模型沒有已串接的 08 參考工作流；多圖角色＋服裝請使用 Qwen Image Edit Plus");
}
