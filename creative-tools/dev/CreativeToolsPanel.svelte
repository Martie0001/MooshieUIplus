<script lang="ts">
  import {
    calculateOutpaintGeometry,
    type OutpaintDirection,
    type OutpaintAmountUnit,
    type OutpaintGeometry,
  } from "../../utils/creativeOutpaint.js";

  import {
    REFERENCE_KINDS, REFERENCE_LABELS, planReferenceHandoff,
    type ReferenceKind, type ReferenceSettings,
  } from "../../utils/creativeReference.js";
  import { checkNodeAvailable } from "../../utils/api.js";
  import { checkStyleTransferNodesReady } from "../../utils/styleTransferNodes.js";
  import { models } from "../../stores/models.svelte.js";
  import { getPresetModel } from "../../config/controlnet-presets.js";
  import CreativePoseEditor from "./CreativePoseEditor.svelte";
  import CreativeComicEditor from "./CreativeComicEditor.svelte";

  type CreativeTool = "reference" | "outpaint" | "pose" | "postprocess" | "comic";
  type ReferencePreview = { name: string; previewUrl: string } | null;
  interface Props {
    selected: CreativeTool;
    hasImage: boolean;
    sourceUrl?: string | null;
    sourceSize?: { width: number; height: number } | null;
    sourceLoading?: boolean;
    busy?: boolean;
    error?: string | null;
    modelName?: string;
    localBackend?: boolean;
    modelFamily?: string;
    referenceImages?: Record<ReferenceKind, ReferencePreview>;
    referenceUploading?: ReferenceKind | null;
    referencePickTarget?: ReferenceKind;
    onReferencePick: (kind: ReferenceKind) => void;
    onReferenceLocal: (kind: ReferenceKind, file: File) => void;
    onReferenceCopy: (from: ReferenceKind, to: ReferenceKind) => void;
    onReferenceClear: (kind: ReferenceKind) => void;
    onReferenceApply: (settings: ReferenceSettings) => void;
    onSelect: (tool: CreativeTool) => void;
    onPickImage: () => void;
    onLocalImage: (file: File) => void;
    onOutpaint: (direction: OutpaintDirection, amount: number, unit: OutpaintAmountUnit, denoise: number) => void;
    onNativeUpscale: (facefix: boolean, upscale: boolean) => void;
    poseWidth: number;
    poseHeight: number;
    onPoseApply: (bytes: number[]) => Promise<void>;
    onPoseDetect: () => Promise<string>;
    onClose: () => void;
  }

  let {
    selected, hasImage, sourceUrl = null, sourceSize = null, sourceLoading = false,
    busy = false, error = null, modelName = "", localBackend = true, modelFamily = "",
    referenceImages = { character: null, outfit: null, style: null },
    referenceUploading = null, referencePickTarget = "character",
    onReferencePick, onReferenceLocal, onReferenceCopy, onReferenceClear, onReferenceApply,
    onSelect, onPickImage, onLocalImage, onOutpaint, onNativeUpscale, onClose,
    poseWidth, poseHeight, onPoseApply, onPoseDetect,
  }: Props = $props();

  const tools: { id: CreativeTool; title: string }[] = [
    { id: "reference", title: "08｜角色／服裝／風格參考" },
    { id: "outpaint", title: "11｜圖片向外延伸" },
    { id: "pose", title: "22｜姿勢控制" },
    { id: "postprocess", title: "31｜自動後製" },
    { id: "comic", title: "40｜漫畫排版與對話框" },
  ];
  const directions: { id: OutpaintDirection; title: string }[] = [
    { id: "top", title: "上" }, { id: "bottom", title: "下" },
    { id: "left", title: "左" }, { id: "right", title: "右" }, { id: "all", title: "四周" },
  ];

  let direction = $state<OutpaintDirection>("right");
  let unit = $state<OutpaintAmountUnit>("percent");
  let percent = $state(25);
  let pixels = $state(256);
  let outpaintDenoise = $state(1);
  let postUpscale = $state(true);
  let postFacefix = $state(false);
  let referenceSettings = $state<ReferenceSettings>({
    character: { enabled: false, strength: 75 },
    outfit: { enabled: false, strength: 75 },
    style: { enabled: false, strength: 60 },
  });
  let referenceExpanded = $state<Record<ReferenceKind, boolean>>({
    character: true, outfit: true, style: true,
  });
  let animaCharacterReady = $state<boolean | null>(null);
  let sdxlAdapterReady = $state<boolean | null>(null);
  $effect(() => {
    const family = modelFamily;
    const enabled = localBackend;
    let cancelled = false;
    animaCharacterReady = null;
    sdxlAdapterReady = null;
    if (enabled && family === "anima") {
      if (!models.loras.some(name => name.endsWith("anima_ref_adapter_v2_r64.safetensors"))) {
        animaCharacterReady = false;
      } else {
        void checkNodeAvailable("AnimaRefAdapter").then(ready => {
          if (!cancelled) animaCharacterReady = ready;
        }).catch(() => { if (!cancelled) animaCharacterReady = false; });
      }
    }
    if (enabled && ["sd15", "sdxl", "illustrious", "pony"].includes(family)) {
      void checkNodeAvailable("IPAdapterUnifiedLoader").then(ready => {
        if (!cancelled) sdxlAdapterReady = ready;
      }).catch(() => { if (!cancelled) sdxlAdapterReady = false; });
    }
    return () => { cancelled = true; };
  });
  const supportedReferenceKinds = $derived.by((): ReferenceKind[] => {
    if (!localBackend || !modelName) return [];
    if (["qwen_edit", "qwen_edit_plus"].includes(modelFamily)) return REFERENCE_KINDS;
    if (modelFamily === "anima") return animaCharacterReady ? ["character", "style"] : ["style"];
    if (["sd15", "sdxl", "illustrious", "pony"].includes(modelFamily) && sdxlAdapterReady) {
      return ["character", "style"];
    }
    return [];
  });
  function enableReference(kind: ReferenceKind) {
    if (modelFamily !== "qwen_edit_plus") {
      for (const other of REFERENCE_KINDS) {
        if (other !== kind) referenceSettings[other].enabled = false;
      }
    }
    referenceSettings[kind].enabled = true;
  }
  const seenReferenceNames: Record<ReferenceKind, string | null> = {
    character: null, outfit: null, style: null,
  };
  $effect(() => {
    for (const kind of REFERENCE_KINDS) {
      const current = referenceImages[kind]?.name ?? null;
      if (current && !seenReferenceNames[kind] && supportedReferenceKinds.includes(kind)) enableReference(kind);
      seenReferenceNames[kind] = current;
    }
  });
  $effect(() => {
    for (const kind of REFERENCE_KINDS) {
      if (!supportedReferenceKinds.includes(kind) && referenceSettings[kind].enabled) referenceSettings[kind].enabled = false;
    }
  });
  const referencePlan = $derived.by(() => {
    try {
      return {
        plan: planReferenceHandoff(modelFamily, {
          character: referenceImages.character?.name ?? null,
          outfit: referenceImages.outfit?.name ?? null,
          style: referenceImages.style?.name ?? null,
        }, referenceSettings),
        error: null,
      };
    } catch (e) {
      return { plan: null, error: e instanceof Error ? e.message : String(e) };
    }
  });

  const referenceRoute = $derived(referencePlan.plan?.route ?? null);
  let dependencyReady = $state<boolean | null>(null);
  let dependencyMessage = $state<string | null>(null);
  $effect(() => {
    const route = selected === "reference" ? referenceRoute : null;
    let cancelled = false;
    dependencyReady = null;
    dependencyMessage = route ? "正在確認模型參考依賴…" : null;
    if (route) {
      void (async () => {
        try {
          let ready = false;
          let message = "";
          if (route === "qwen_edit") {
            ready = true;
            message = "原生 Image Edit 參考圖輸入已串接；實際生成效果尚未驗收";
          } else if (route === "anima_character") {
            const node = await checkNodeAvailable("AnimaRefAdapter");
            const lora = models.loras.some(name => name.endsWith("anima_ref_adapter_v2_r64.safetensors"));
            ready = node && lora;
            message = ready ? "Anima 角色參考依賴已偵測" :
              "缺少 AnimaRefAdapter 節點或參考 LoRA，請至原生參考區確認";
          } else if (route === "anima_style") {
            ready = await checkStyleTransferNodesReady();
            message = ready ? "Anima 風格轉換節點已偵測" :
              "缺少 Untwisting RoPE 或 ImageScaleToTotalPixelsX 節點";
          } else {
            ready = await checkNodeAvailable("IPAdapterUnifiedLoader");
            message = ready ? "IP-Adapter Plus 節點已偵測；仍需相容權重" :
              "缺少 IPAdapterUnifiedLoader 節點，請至原生參考區確認";
          }
          if (!cancelled) { dependencyReady = ready; dependencyMessage = message; }
        } catch {
          if (!cancelled) { dependencyReady = false; dependencyMessage = "無法連線確認參考依賴"; }
        }
      })();
    }
    return () => { cancelled = true; };
  });

  const amount = $derived(unit === "percent" ? percent : pixels);
  const preview = $derived.by((): { geometry: OutpaintGeometry | null; error: string | null } => {
    if (!sourceSize) return { geometry: null, error: null };
    try {
      return {
        geometry: calculateOutpaintGeometry(sourceSize.width, sourceSize.height, direction, unit, amount),
        error: null,
      };
    } catch (e) {
      return { geometry: null, error: e instanceof Error ? e.message : String(e) };
    }
  });
  const usable = $derived(hasImage && !sourceLoading && !busy && localBackend && !!modelName);
  const poseModelEntry = $derived(
    ["anima", "illustrious", "sdxl", "pony", "kolors", "sd15"].includes(modelFamily)
      ? getPresetModel("openpose", modelFamily) : null,
  );
  const poseWeightReady = $derived(!!poseModelEntry &&
    (modelFamily === "anima" ? models.modelPatches : models.controlnetModels).includes(poseModelEntry.filename));
  let poseNodesReady = $state<boolean | null>(null);
  $effect(() => {
    if (selected !== "pose" || !localBackend || !poseModelEntry || !poseWeightReady) {
      poseNodesReady = null;
      return;
    }
    let cancelled = false;
    poseNodesReady = null;
    const nodes = modelFamily === "anima"
      ? [checkNodeAvailable("ModelPatchLoader"), checkNodeAvailable("AnimaLLLiteApply", ["model_patch"])]
      : [checkNodeAvailable("ControlNetLoader"), checkNodeAvailable("ControlNetApplyAdvanced")];
    void Promise.all(nodes).then(values => {
      if (!cancelled) poseNodesReady = values.every(Boolean);
    }).catch(() => {
      if (!cancelled) poseNodesReady = false;
    });
    return () => { cancelled = true; };
  });
  const poseUsable = $derived(localBackend && !!modelName && poseWeightReady && poseNodesReady === true && !busy);
  const poseAvailability = $derived(!localBackend ? "目前模型來源不是本地 ComfyUI" :
    !modelName ? "請先選擇模型" :
    !poseModelEntry ? "此模型尚無已確認的姿勢控制權重（Qwen 等暫未開放）" :
    !poseWeightReady ? `缺少相容權重：${poseModelEntry.filename}，目前不會自動下載` :
    poseNodesReady === null ? "正在檢查姿勢控制節點…" :
    poseNodesReady ? modelFamily === "anima"
      ? "已偵測 Anima LLLite Pose；屬柔性姿勢引導，手部／臉部細節無法由目前骨架編輯器完整控制"
      : "ControlNet 節點與姿勢權重已偵測，可帶入原生流程（生圖品質尚未驗收）"
    : modelFamily === "anima" ? "缺少 ModelPatchLoader 或原生 AnimaLLLiteApply 節點" :
      "缺少 ControlNetLoader 或 ControlNetApplyAdvanced，無法交接");
</script>

<div class="flex h-full min-h-0 flex-col gap-3 overflow-hidden p-4 text-neutral-200">
  <div class="flex shrink-0 flex-wrap items-center justify-between gap-2">
    <h2 class="text-base font-semibold">creative-tools</h2>
    <button class="rounded-lg border border-neutral-700 px-3 py-1.5 text-xs hover:bg-neutral-800" onclick={onClose}>
      返回生圖
    </button>
  </div>

  <nav class="flex shrink-0 gap-2 overflow-x-auto pb-1" aria-label="Creative tools">
    {#each tools as tool}
      <button
        aria-current={selected === tool.id ? "page" : undefined}
        class="shrink-0 rounded-lg px-3 py-2 text-xs transition-colors {selected === tool.id ? 'bg-indigo-600 font-semibold text-white' : 'bg-neutral-800 hover:bg-neutral-700'}"
        onclick={() => onSelect(tool.id)}
      >{tool.title}</button>
    {/each}
  </nav>

  <div class="min-h-0 flex-1 space-y-4 overflow-y-auto pb-4">
    {#if selected !== "comic"}
      <div class="rounded-lg border border-neutral-800 bg-neutral-900/70 px-3 py-2 text-xs text-neutral-400">
        模型：{modelName || "尚未選擇"}　｜　{localBackend ? "ComfyUI 本地執行" : "目前模型模式不支援工具執行"}
      </div>
    {/if}

    {#if selected === "outpaint" || selected === "postprocess"}
      <div class="grid grid-cols-1 gap-4 2xl:grid-cols-2">
        <section class="space-y-3 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
          <h3 class="font-semibold">01　來源圖片</h3>
          <div class="flex flex-wrap items-center gap-3">
            <button class="rounded-lg border border-neutral-600 bg-neutral-800 px-3 py-2 text-xs hover:bg-neutral-700" onclick={onPickImage}>從圖庫選擇</button>
            <label class="text-xs text-neutral-300">
              本地上傳
              <input class="mt-1 block w-full max-w-48 text-xs" type="file" accept="image/png,image/jpeg,image/webp" disabled={busy}
                onchange={(event) => { const file = event.currentTarget.files?.[0]; if (file) onLocalImage(file); }} />
            </label>
          </div>
          <div class="flex min-h-40 flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-neutral-700 bg-neutral-950/50 p-3">
            {#if sourceUrl && hasImage}
              <img src={sourceUrl} alt="選取的原始圖片" class="max-h-52 w-full object-contain" />
            {:else}
              <p class="text-xs text-neutral-400">尚未選擇圖片</p>
              <p class="text-xs text-neutral-500">可從本地上傳，或在下方圖庫對圖片按右鍵</p>
            {/if}
          </div>
          {#if selected === "outpaint"}
            {#if sourceLoading}
              <p class="text-xs text-neutral-400">正在讀取來源尺寸…</p>
            {:else if sourceSize}
              <p class="text-xs text-neutral-400">擴圖來源尺寸：{sourceSize.width} × {sourceSize.height} px（依局部重繪 4MP 上限正規化後）</p>
            {/if}
          {/if}
          <p class="text-xs text-neutral-500">不會覆蓋原始圖片。</p>
        </section>

        {#if selected === "outpaint"}
          <section class="space-y-4 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
            <h3 class="font-semibold">02　延伸設定</h3>
            <div class="space-y-2">
              <p class="text-xs font-medium text-neutral-300">延伸方向</p>
              <div class="flex flex-wrap gap-2">
                {#each directions as option}
                  <button
                    aria-pressed={direction === option.id}
                    class="rounded-lg border px-3 py-2 text-xs {direction === option.id ? 'border-indigo-400 bg-indigo-600/30 text-white' : 'border-neutral-700 bg-neutral-800 hover:bg-neutral-700'}"
                    onclick={() => direction = option.id}
                  >{option.title}</button>
                {/each}
              </div>
            </div>
            <div class="space-y-2">
              <p class="text-xs font-medium text-neutral-300">延伸範圍</p>
              <div class="inline-flex gap-1 rounded-lg bg-neutral-950 p-1">
                <button aria-pressed={unit === "percent"}
                  class="rounded-md px-3 py-1.5 text-xs {unit === 'percent' ? 'bg-indigo-600 text-white' : 'text-neutral-400 hover:text-white'}"
                  onclick={() => unit = "percent"}>百分比 (%)</button>
                <button aria-pressed={unit === "pixels"}
                  class="rounded-md px-3 py-1.5 text-xs {unit === 'pixels' ? 'bg-indigo-600 text-white' : 'text-neutral-400 hover:text-white'}"
                  onclick={() => unit = "pixels"}>像素 (px)</button>
              </div>
              {#if unit === "percent"}
                <label class="flex items-center justify-between gap-2 text-xs">
                  <span>延伸比例</span>
                  <span class="flex items-center gap-1">
                    <input class="w-20 rounded border border-neutral-700 bg-neutral-800 p-2 text-right" type="number" min="5" max="100" step="5" bind:value={percent} />
                    %
                  </span>
                </label>
                <input aria-label="延伸百分比" class="w-full accent-indigo-500" type="range" min="5" max="100" step="5" bind:value={percent} />
                <p class="text-xs text-neutral-500">左右依原圖寬度、上下依原圖高度，四周分別計算。</p>
              {:else}
                <label class="flex items-center justify-between gap-2 text-xs">
                  <span>延伸像素</span>
                  <span class="flex items-center gap-1">
                    <input class="w-20 rounded border border-neutral-700 bg-neutral-800 p-2 text-right" type="number" min="64" max="768" step="8" bind:value={pixels} />
                    px
                  </span>
                </label>
                <input aria-label="延伸像素" class="w-full accent-indigo-500" type="range" min="64" max="768" step="8" bind:value={pixels} />
                <p class="text-xs text-neutral-500">每個選定方向套用相同像素量。</p>
              {/if}
            </div>
            <div class="space-y-1">
              <div class="flex justify-between gap-2 text-xs text-neutral-300">
                <span>延伸區重繪強度（僅適用本次擴圖）</span>
                <span>{Math.round(outpaintDenoise * 100)}%</span>
              </div>
              <input aria-label="延伸區重繪強度" type="range" class="w-full accent-indigo-500" min="0.85" max="1" step="0.05" bind:value={outpaintDenoise} />
              <p class="text-xs text-neutral-500">預設 100%；延伸底圖改用原圖邊緣色彩，不使用灰色填充。一般圖生圖／局部重繪的 Denoise 不受影響。</p>
            </div>
            <p class="text-xs text-neutral-400">模型與提示詞沿用目前設定。請讓提示詞符合原圖主體及背景；不相關的角色 TAG／LoRA 可能導致延伸區畫風不一致。</p>
          </section>
        {:else}
          <section class="space-y-4 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
            <h3 class="font-semibold">02　後製功能</h3>
            <label class="flex cursor-pointer items-start gap-3 rounded-lg border border-neutral-700 bg-neutral-800/60 p-3">
              <input class="mt-1 accent-indigo-500" type="checkbox" bind:checked={postUpscale} />
              <span><span class="block text-sm font-medium">圖片放大</span><span class="block text-xs text-neutral-400">沿用原生 Upscale 模型及參數</span></span>
            </label>
            <label class="flex cursor-pointer items-start gap-3 rounded-lg border border-neutral-700 bg-neutral-800/60 p-3">
              <input class="mt-1 accent-indigo-500" type="checkbox" bind:checked={postFacefix} />
              <span><span class="block text-sm font-medium">臉部修復</span><span class="block text-xs text-neutral-400">沿用原生 Face Fix；執行時可能需要偵測模型</span></span>
            </label>
            <div class="flex items-start gap-3 rounded-lg border border-neutral-800 bg-neutral-950/60 p-3 opacity-60">
              <input class="mt-1" type="checkbox" disabled aria-label="降噪／細節修復（尚未串接）" />
              <span><span class="block text-sm">降噪／細節修復</span><span class="block text-xs text-neutral-400">尚未串接，不能執行</span></span>
            </div>
          </section>
        {/if}
      </div>

      {#if selected === "outpaint"}
        <section class="space-y-3 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
          <h3 class="font-semibold">03　延伸預覽</h3>
          {#if preview.geometry && sourceSize}
            <div class="grid grid-cols-1 items-center gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
              <div class="mx-auto w-full max-w-96">
                <div class="relative w-full overflow-hidden rounded-lg border-2 border-dashed border-indigo-500/70 bg-neutral-700/80" style={`aspect-ratio: ${preview.geometry.width} / ${preview.geometry.height};`}>
                  {#if sourceUrl}
                    <img src={sourceUrl} alt="延伸範圍示意，原圖區域不重繪" class="absolute max-w-none object-fill"
                      style={`left:${preview.geometry.left / preview.geometry.width * 100}%; top:${preview.geometry.top / preview.geometry.height * 100}%; width:${sourceSize.width / preview.geometry.width * 100}%; height:${sourceSize.height / preview.geometry.height * 100}%;`} />
                  {/if}
                </div>
                <p class="mt-1 text-center text-xs text-neutral-500">灰色僅為介面標示，實際底圖使用原圖邊緣延續色；建立後須按「生成」。</p>
              </div>
              <div class="space-y-1 text-xs text-neutral-300">
                <p>原始：{sourceSize.width} × {sourceSize.height} px</p>
                <p class="font-semibold text-white">延伸後：{preview.geometry.width} × {preview.geometry.height} px</p>
                <p>左：{preview.geometry.left} px　右：{preview.geometry.right} px</p>
                <p>上：{preview.geometry.top} px　下：{preview.geometry.bottom} px</p>
                <p class="pt-2 text-neutral-500">尺寸依 8px 格線對齊，總面積上限 4MP。</p>
              </div>
            </div>
          {:else if preview.error}
            <p role="alert" class="rounded-lg border border-amber-800/60 p-3 text-xs text-amber-300">{preview.error}</p>
          {:else}
            <p class="text-xs text-neutral-400">選擇圖片後，這裡會依實際圖片尺寸顯示延伸範圍。</p>
          {/if}
        </section>
        <section class="space-y-2 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
          <h3 class="font-semibold">04　執行</h3>
          <p class="text-xs text-neutral-400">先建立擴圖畫布及遮罩，再回到原生局部重繪頁確認提示詞並按「生成」。</p>
          <button disabled={!usable || !preview.geometry} class="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-semibold text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-40"
            onclick={() => onOutpaint(direction, amount, unit, outpaintDenoise)}>{busy ? "準備中…" : "建立擴圖畫布及遮罩"}</button>
        </section>
      {:else}
        <section class="space-y-3 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
          <h3 class="font-semibold">03　後製預覽及執行</h3>
          <div class="grid grid-cols-2 gap-3">
            <div class="flex min-h-32 flex-col items-center justify-center gap-2 rounded-lg border border-neutral-700 bg-neutral-950/60 p-2">
              {#if sourceUrl && hasImage}<img src={sourceUrl} alt="後製前原圖" class="max-h-48 w-full object-contain" />{/if}
              <p class="text-xs text-neutral-300">原始圖片</p>
            </div>
            <div class="flex min-h-32 items-center justify-center rounded-lg border border-dashed border-neutral-700 bg-neutral-950/60 p-2">
              <p class="text-center text-xs text-neutral-500">處理後圖片會出現在原生圖庫，目前尚無結果</p>
            </div>
          </div>
          <p class="text-xs text-neutral-400">此步驟只會將已選的後製項目帶入原生流程，不會自動生成或覆蓋原圖。</p>
          <button disabled={!usable || (!postUpscale && !postFacefix)}
            class="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-semibold text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-40"
            onclick={() => onNativeUpscale(postFacefix, postUpscale)}>{busy ? "準備中…" : "帶入原生後製流程"}</button>
        </section>
      {/if}
    {:else if selected === "reference"}
      <section class="space-y-2 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
        <h3 class="font-semibold">08｜角色／服裝／風格獨立參考</h3>
        <p class="text-xs text-neutral-400">分別指定用途，可重用同一張圖；勾選後才會交給模型。原圖與參考圖不會被覆蓋。</p>
        <p class="text-xs text-neutral-500">依目前模型及已安裝的 ComfyUI 節點顯示可用參考槽。Qwen Edit Plus 最多三圖；Anima／SDXL 路線每次只用一張。</p>
        {#if modelFamily === "anima"}
          <p class="text-xs text-amber-300">Anima 不支援獨立服裝參考。{animaCharacterReady === true ? "角色參考依賴已找到。" : "未偵測到完整 Anima 角色參考依賴，暫不提供角色槽；"}畫風參考仍須通過原生節點檢查。</p>
        {:else if ["sd15", "sdxl", "illustrious", "pony"].includes(modelFamily) && sdxlAdapterReady !== true}
          <p class="text-xs text-amber-300">IP-Adapter 節點尚未偵測到，參考槽暫不可用。</p>
        {/if}
        {#if supportedReferenceKinds.length === 0}
          <p class="text-xs text-amber-300">目前模型沒有已確認可執行的參考路線，請選擇支援的模型或安裝必要節點。</p>
        {/if}
      </section>
      <div class="flex flex-col gap-3">
        {#each supportedReferenceKinds as kind (kind)}
          <section class="rounded-xl border {referencePickTarget === kind ? 'border-indigo-500/70' : 'border-neutral-700'} bg-neutral-900/60">
            <div class="flex items-center justify-between gap-3 px-4 py-3">
              <button type="button" class="flex min-w-0 flex-1 items-center gap-2 text-left hover:text-white"
                aria-expanded={referenceExpanded[kind]}
                aria-controls={"creative-reference-" + kind}
                onclick={() => referenceExpanded[kind] = !referenceExpanded[kind]}>
                <span class="text-sm font-semibold">0{REFERENCE_KINDS.indexOf(kind) + 1}｜{REFERENCE_LABELS[kind]}</span>
                {#if referenceImages[kind]}
                  <span class="truncate text-[11px] text-neutral-500">已選參考圖</span>
                {/if}
                <span aria-hidden="true" class="ml-auto text-xs text-neutral-500">{referenceExpanded[kind] ? "▲" : "▼"}</span>
              </button>
              <label class="flex shrink-0 items-center gap-1.5 text-xs text-neutral-300">
                <input type="checkbox" class="accent-indigo-500" checked={referenceSettings[kind].enabled}
                  onchange={(event) => { if (event.currentTarget.checked) enableReference(kind); else referenceSettings[kind].enabled = false; }} />
                啟用
              </label>
            </div>
            {#if referenceExpanded[kind]}
              <div id={"creative-reference-" + kind} class="flex flex-col gap-3 border-t border-neutral-800 px-4 py-3 sm:flex-row">
                <div class="flex h-28 w-full shrink-0 flex-col items-center justify-center gap-1 overflow-hidden rounded-lg border border-dashed border-neutral-700 bg-neutral-950/60 p-2 sm:w-32">
                  {#if referenceImages[kind]}
                    <img src={referenceImages[kind]?.previewUrl} alt={REFERENCE_LABELS[kind]} class="min-h-0 max-h-20 w-full flex-1 object-contain" />
                    <span class="w-full truncate text-[10px] text-neutral-400" title={referenceImages[kind]?.name}>{referenceImages[kind]?.name}</span>
                  {:else}
                    <span class="text-center text-xs text-neutral-500">尚未選擇圖片</span>
                  {/if}
                </div>
                <div class="flex min-w-0 flex-1 flex-col gap-2">
                  <div class="flex flex-wrap items-center gap-2 text-xs">
                    <label class="cursor-pointer rounded-lg border border-neutral-600 bg-neutral-800 px-3 py-1.5 hover:bg-neutral-700">
                      {referenceImages[kind] ? "更換檔案" : "本地上傳"}
                      <input type="file" class="hidden" accept="image/png,image/jpeg,image/webp"
                        disabled={busy || referenceUploading !== null}
                        onchange={(event) => {
                          const file = event.currentTarget.files?.[0];
                          if (file) { enableReference(kind); onReferenceLocal(kind, file); }
                          event.currentTarget.value = "";
                        }} />
                    </label>
                    <button class="rounded-lg border border-neutral-600 bg-neutral-800 px-3 py-1.5 hover:bg-neutral-700"
                      disabled={busy || referenceUploading !== null}
                      onclick={() => { enableReference(kind); onReferencePick(kind); }}>
                      {referencePickTarget === kind ? "從圖庫選擇 ✓" : "從圖庫選擇"}
                    </button>
                    {#if referenceImages[kind]}
                      <button class="rounded-lg border border-red-900/70 px-3 py-1.5 text-red-300 hover:bg-red-950/50"
                        disabled={busy} onclick={() => { referenceSettings[kind].enabled = false; onReferenceClear(kind); }}>移除</button>
                    {/if}
                  </div>
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="text-[11px] text-neutral-500">沿用其他圖片：</span>
                    {#each REFERENCE_KINDS.filter(other => other !== kind && !!referenceImages[other]) as other}
                      <button class="rounded border border-neutral-700 px-2 py-1 text-[11px] hover:bg-neutral-800"
                        disabled={busy || referenceUploading !== null}
                        onclick={() => { enableReference(kind); onReferenceCopy(other, kind); }}>{REFERENCE_LABELS[other]}</button>
                    {/each}
                  </div>
                  <div class="space-y-1">
                    <div class="flex justify-between gap-2 text-xs text-neutral-400">
                      <span>{modelFamily.startsWith("qwen_edit") ? "語意參考強度" : "參考強度"}</span>
                      <span>{referenceSettings[kind].strength}%</span>
                    </div>
                    <input class="w-full accent-indigo-500" type="range" min="10" max="100" step="5"
                      bind:value={referenceSettings[kind].strength} disabled={!referenceSettings[kind].enabled} />
                  </div>
                  {#if referenceUploading === kind}
                    <p class="text-xs text-indigo-300">正在處理參考圖…</p>
                  {/if}
                </div>
              </div>
            {/if}
          </section>
        {/each}
      </div>
      <section class="space-y-3 rounded-xl border border-neutral-700 bg-neutral-900/60 p-4">
        <h3 class="font-semibold">參考配置與交接</h3>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div class="min-h-28 space-y-2 rounded-lg border border-neutral-700 bg-neutral-950/50 p-3">
            <p class="text-xs font-medium text-neutral-300">參考組合</p>
            {#if referencePlan.plan}
              {#each referencePlan.plan.ordered as kind, i}
                <p class="text-xs text-neutral-300">圖片 {i + 1} → {REFERENCE_LABELS[kind]}（{referenceSettings[kind].strength}%）</p>
              {/each}
            {:else}
              <p role="status" class="text-xs text-amber-300">{referencePlan.error}</p>
            {/if}
          </div>
          <div class="min-h-28 space-y-2 rounded-lg border border-dashed border-neutral-700 bg-neutral-950/50 p-3">
            <p class="text-xs font-medium text-neutral-300">生成結果</p>
            <p class="text-xs text-neutral-500">交接到原生生圖後，在下方圖庫查看結果；此處不展示虛構預覽。</p>
          </div>
        </div>
        {#if referencePlan.plan && dependencyMessage}
          <p role="status" class="text-xs {dependencyReady ? 'text-neutral-400' : 'text-amber-300'}">{dependencyMessage}</p>
        {/if}
        <p class="text-xs text-neutral-400">按下後只帶入原生流程，請確認提示詞、模型與設定後再按「生成」。Anima 畫風轉換會依原生需求調整採樣器並停用 ControlNet／放大／臉修。</p>
        <button class="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-semibold text-white hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-40"
          disabled={!localBackend || !modelName || busy || referenceUploading !== null || !referencePlan.plan || dependencyReady !== true}
          onclick={() => onReferenceApply(referenceSettings)}>
          {busy || referenceUploading !== null ? "準備中…" : "帶入原生參考流程"}
        </button>
      </section>
    {/if}
    <!-- Keep the pose editor mounted while switching tools so edits are not discarded. -->
    <div class={selected === "pose" ? "" : "hidden"}>
      <CreativePoseEditor width={poseWidth} height={poseHeight} {sourceUrl} {sourceSize} {busy}
        canApply={poseUsable} availability={poseAvailability}
        {onPickImage} {onLocalImage} onDetect={onPoseDetect} onApply={onPoseApply} />
    </div>
    <!-- Keep the comic project mounted so switching tools retains unsaved edits. -->
    <div class={selected === "comic" ? "h-full min-h-[560px]" : "hidden"}>
      <CreativeComicEditor />
    </div>

    {#if error}
      <p role="alert" class="rounded-lg border border-red-700/60 bg-red-950/30 p-3 text-xs text-red-300">{error}</p>
    {/if}
  </div>
</div>
