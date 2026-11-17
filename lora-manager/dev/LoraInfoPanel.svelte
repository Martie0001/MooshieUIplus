<script lang="ts">
  import { onMount } from "svelte";
  import { models } from "../../stores/models.svelte.js";
  import { generation } from "../../stores/generation.svelte.js";
  import { gallery } from "../../stores/gallery.svelte.js";
  import { loraKeywords } from "../../stores/loraKeywords.svelte.js";
  import GalleryPickerModal from "../../components/gallery/GalleryPickerModal.svelte";
  import { getLoraCivitaiInfo, type LoraCivitaiInfo } from "../../utils/api.js";
  import { ipcInvoke } from "../../utils/ipc.js";
  import type { OutputImage } from "../../types/index.js";

  type LoraType = "style" | "character" | "clothing" | "effect" | "other";
  type Entry = { types: LoraType[]; tags: string[]; triggerWords: string[]; baseModel: string; notes: string };
  type Catalog = { entries: Record<string, Partial<Entry>>; types: Record<string, LoraType[]> };
  type LoadResult = { entry: Partial<Entry> | null; types: LoraType[] | null };
  const typeOptions: { key: LoraType; label: string }[] = [
    { key: "style", label: "風格" }, { key: "character", label: "角色" },
    { key: "clothing", label: "服裝" }, { key: "effect", label: "效果" }, { key: "other", label: "其他" },
  ];
  const call = <T,>(action: string, filename = "", extra: Record<string, unknown> = {}): Promise<T> =>
    ipcInvoke("lora_info_action", { action, filename, ...extra });

  let catalog = $state<Catalog>({ entries: {}, types: {} });
  let selected = $state("");
  let query = $state("");
  let loaded = $state(false);
  let busy = $state(false);
  let status = $state("");
  let error = $state("");
  let types = $state<LoraType[]>([]);
  let tags = $state<string[]>([]);
  let newTag = $state("");
  let triggers = $state("");
  let notes = $state("");
  let baseModel = $state("");
  let metadata = $state<LoraCivitaiInfo | null>(null);
  let galleryPickerOpen = $state(false);
  let galleryCover = $state("");
  let fileCover = $state<File | null>(null);
  let localPreview = $state("");
  let currentPreview = $state("");

  const candidates = $derived.by(() => {
    const q = query.trim().toLowerCase();
    return models.loras.filter(name => {
      if (!q) return true;
      const entry = catalog.entries[name] ?? {};
      return name.toLowerCase().includes(q) || (entry.tags ?? []).some(tag => tag.toLowerCase().includes(q));
    });
  });

  onMount(() => { void refreshCatalog(); });

  async function refreshCatalog() {
    try {
      catalog = await call<Catalog>("list");
      error = "";
    } catch (e) { error = String(e); }
  }

  function clearPreview() {
    if (localPreview) URL.revokeObjectURL(localPreview);
    localPreview = "";
    fileCover = null;
    galleryCover = "";
  }

  async function loadSelected() {
    if (!selected) return;
    busy = true;
    error = "";
    status = "";
    clearPreview();
    metadata = null;
    loaded = false;
    const filename = selected;
    try {
      const saved = await call<LoadResult>("load", filename);
      if (selected !== filename) return;
      const entry = saved.entry;
      types = [...(saved.types ?? entry?.types ?? [])];
      tags = [...(entry?.tags ?? [])];
      triggers = (entry?.triggerWords ?? []).join("\n");
      notes = entry?.notes ?? "";
      baseModel = entry?.baseModel ?? "";
      loaded = true;
      // Source information is display-only. It never silently turns into user annotations.
      try {
        const info = await getLoraCivitaiInfo(filename);
        if (selected !== filename) return;
        metadata = info;
        currentPreview = info.thumbnail_url ?? info.civitai_images?.[0]?.url ?? "";
      } catch {
        currentPreview = "";
        status = "自訂資訊已載入。模型來源資料無法取得時，Trigger Words 保持空白。";
      }
    } catch (e) { error = String(e); }
    finally { busy = false; }
  }

  function toggleType(key: LoraType) {
    types = types.includes(key) ? types.filter(t => t !== key) : [...types, key];
  }

  function addTag() {
    const value = newTag.trim();
    if (value && !tags.includes(value)) tags = [...tags, value];
    newTag = "";
  }

  function putInPrompt(word: string) {
    const cleaned = word.trim();
    if (!cleaned) return;
    const prompt = generation.positivePrompt.trim();
    if (prompt.split(",").map(p => p.trim()).includes(cleaned)) return;
    generation.positivePrompt = prompt ? `${prompt}, ${cleaned}` : cleaned;
    generation.recordInsertedLoraWord(selected, cleaned);
    generation.saveSettings();
    status = "已加入生圖 Prompt";
  }

  function chooseFile(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/") || file.size > 15 * 1024 * 1024) {
      error = "請選擇 15 MB 以下的圖片";
      input.value = "";
      return;
    }
    clearPreview();
    fileCover = file;
    localPreview = URL.createObjectURL(file);
    input.value = "";
    error = "";
  }

  async function onGallerySelect(images: OutputImage[]) {
    const image = images[0];
    if (!image) return;
    clearPreview();
    const filename = await gallery.resolveGalleryFilename(image);
    if (!filename) {
      error = "這張圖片尚未保存至圖庫";
      return;
    }
    galleryCover = filename;
    status = "已選擇圖庫圖片，儲存時將設成 LoRA 封面。";
  }

  async function save() {
    if (!loaded || !selected || busy) return;
    if (!types.length) { error = "請先選擇至少一個 LoRA 類型"; return; }
    const words = [...new Set(triggers.split(/[,\n]/).map(v => v.trim()).filter(Boolean))];
    const record: Entry = {
      types, tags: [...new Set(tags.map(v => v.trim()).filter(Boolean))],
      triggerWords: words, baseModel: baseModel.trim(), notes: notes.trim(),
    };
    busy = true;
    error = "";
    status = "";
    try {
      if (fileCover || galleryCover) {
        if (currentPreview && !confirm("要更換此 LoRA 現有封面嗎？")) return;
        const extra = fileCover
          ? { imageBytes: Array.from(new Uint8Array(await fileCover.arrayBuffer())) }
          : { galleryFilename: galleryCover };
        await call("cover", selected, extra);
      }
      await call("save", selected, { entry: record });
      if (fileCover || galleryCover) {
        // Switching back to the LoRA tab remounts its gallery. Discard only this
        // model's thumbnail cache so the newly saved Sidecar is read.
        try {
          const key = "mooshieui.lora.civitai.cache.v3";
          const cache = JSON.parse(localStorage.getItem(key) ?? "{}");
          delete cache[selected];
          localStorage.setItem(key, JSON.stringify(cache));
        } catch { /* Cache invalidation is optional; saved Sidecar remains authoritative. */ }
        try {
          const refreshed = await getLoraCivitaiInfo(selected);
          metadata = refreshed;
          currentPreview = refreshed.thumbnail_url ?? refreshed.civitai_images?.[0]?.url ?? "";
        } catch {
          // Re-fetch is only a preview refresh, not part of the successful save.
          currentPreview = "";
        }
      }
      catalog.entries[selected] = record;
      catalog.types[selected] = [...types];
      catalog = { entries: { ...catalog.entries }, types: { ...catalog.types } };
      // Existing prompt autocomplete can immediately use the manually-confirmed words.
      loraKeywords.ingest(selected, {
        filename: selected, civitai_images: [], civitai_trigger_words: words,
      });
      clearPreview();
      window.dispatchEvent(new CustomEvent("mooshieui:lora-category-updated", { detail: { filename: selected, types: [...types] } }));
      status = "資訊已儲存；LoRA 類型篩選已同步更新。";
      await refreshCatalog();
    } catch (e) { error = String(e); }
    finally { busy = false; }
  }

  function cancel() {
    clearPreview();
    loaded = false;
    metadata = null;
    status = "";
    error = "";
  }
</script>

<div class="flex h-full min-h-0 flex-col gap-2 overflow-y-auto p-3 text-xs text-neutral-200">
  <div class="flex flex-wrap items-center gap-2">
    <h3 class="font-medium text-sm">LoRA 資訊管理</h3>
    <span class="text-neutral-500">按需載入，不變更模型權重</span>
  </div>
  <div class="flex flex-wrap gap-2">
    <input type="search" bind:value={query} placeholder="搜尋 LoRA 名稱或自訂標籤"
      class="min-w-40 flex-1 rounded border border-neutral-700 bg-neutral-800 px-2 py-1.5 text-neutral-100" />
    <select bind:value={selected} onchange={() => cancel()} aria-label="選擇 LoRA"
      class="min-w-52 flex-2 rounded border border-neutral-700 bg-neutral-800 px-2 py-1.5">
      <option value="">選擇本地 LoRA</option>
      {#each candidates as filename (filename)}
        <option value={filename}>{filename}</option>
      {/each}
    </select>
    <button type="button" disabled={!selected || busy} onclick={() => void loadSelected()}
      class="rounded border border-indigo-500/60 px-3 py-1.5 disabled:opacity-40">載入資訊</button>
  </div>
  {#if error}<p role="alert" class="text-amber-300 break-all">{error}</p>{/if}
  {#if status}<p class="text-sky-300">{status}</p>{/if}
  {#if loaded}
    <div class="grid grid-cols-1 gap-3 md:grid-cols-[minmax(190px,1fr)_minmax(280px,2fr)]">
      <div class="space-y-2">
        <p class="break-all text-neutral-400">模型：{selected}</p>
        <div class="flex min-h-32 items-center justify-center rounded border border-neutral-700 bg-neutral-950">
          {#if localPreview || currentPreview}
            <img alt="目前 LoRA 封面" src={localPreview || currentPreview} class="max-h-48 w-full object-contain" />
          {:else}
            <span class="text-neutral-500">尚無封面</span>
          {/if}
        </div>
        {#if galleryCover}<p class="text-[11px] text-sky-300">圖庫選擇：{galleryCover}</p>{/if}
        <div class="flex flex-wrap items-center gap-2">
          <label class="cursor-pointer rounded border border-neutral-600 px-2 py-1.5">
            本機上傳 <input type="file" accept="image/png,image/jpeg,image/webp" onchange={chooseFile} class="hidden" />
          </label>
          <button type="button" class="rounded border border-neutral-600 px-2 py-1.5"
            onclick={() => galleryPickerOpen = true}>從圖庫選擇</button>
        </div>
        <div class="space-y-1">
          <p class="text-neutral-400">模型原始資訊（唯讀）</p>
          <p>架構：{metadata?.modelspec_architecture ?? "未取得"}</p>
          <p>來源底模：{metadata?.civitai_base_model ?? "未取得"}</p>
          <p>來源觸發詞：{metadata?.civitai_trigger_words?.join(", ") || metadata?.modelspec_trigger_phrase || "未確認"}</p>
        </div>
      </div>
      <div class="space-y-3">
        <fieldset class="rounded border border-neutral-700 p-2">
          <legend class="px-1 text-neutral-400">LoRA 類型（可複選）</legend>
          <div class="flex flex-wrap gap-3">
            {#each typeOptions as option (option.key)}
              <label class="flex items-center gap-1"><input type="checkbox" checked={types.includes(option.key)}
                onchange={() => toggleType(option.key)} />{option.label}</label>
            {/each}
          </div>
        </fieldset>
        <div class="space-y-1">
          <label for="lora-info-tags">自訂標籤（可直接修改文字）</label>
          <div class="flex flex-wrap gap-1">
            {#each tags as tag, i (i)}
              <div class="flex items-center rounded border border-neutral-700">
                <input aria-label="編輯標籤" class="w-28 bg-transparent px-1.5 py-1" value={tag}
                  oninput={e => { tags[i] = e.currentTarget.value; }} />
                <button type="button" class="px-1.5 text-red-300" aria-label="刪除此標籤"
                  onclick={() => tags = tags.filter((_, n) => n !== i)}>×</button>
              </div>
            {/each}
          </div>
          <div class="flex gap-1">
            <input id="lora-info-tags" bind:value={newTag} placeholder="輸入標籤"
              onkeydown={e => { if (e.key === "Enter") { e.preventDefault(); addTag(); } }}
              class="min-w-0 flex-1 rounded border border-neutral-700 bg-neutral-800 px-2 py-1.5" />
            <button type="button" onclick={addTag} class="rounded border border-neutral-600 px-3">新增</button>
          </div>
        </div>
        <div class="space-y-1">
          <label for="lora-info-triggers">Trigger Words（每行一個；只保存手動確認的內容）</label>
          <textarea id="lora-info-triggers" bind:value={triggers} rows={2}
            class="w-full rounded border border-neutral-700 bg-neutral-800 p-2" placeholder="未確認時保持空白"></textarea>
          {#if !triggers.trim() && (metadata?.civitai_trigger_words?.length || metadata?.modelspec_trigger_phrase)}
            <button type="button" class="text-indigo-300 underline" onclick={() =>
              triggers = (metadata?.civitai_trigger_words?.length ? metadata.civitai_trigger_words : [metadata?.modelspec_trigger_phrase ?? ""]).join("\n")}>
              採用來源已記錄的 Trigger Words
            </button>
          {/if}
          <div class="flex flex-wrap gap-1">
            {#each triggers.split(/[,\n]/).map(v => v.trim()).filter(Boolean) as word (word)}
              <button type="button" class="rounded border border-indigo-700/50 px-2 py-0.5 text-indigo-300"
                title="加入正面提示詞" onclick={() => putInPrompt(word)}>{word} ＋</button>
            {/each}
          </div>
        </div>
        <div class="space-y-1">
          <label for="lora-info-base">適用底模（自行確認後輸入）</label>
          <input id="lora-info-base" bind:value={baseModel} class="w-full rounded border border-neutral-700 bg-neutral-800 px-2 py-1.5" />
        </div>
        <div class="space-y-1">
          <label for="lora-info-notes">模型備註</label>
          <textarea id="lora-info-notes" bind:value={notes} rows={3}
            placeholder="模型特色、建議用途與注意事項" class="w-full rounded border border-neutral-700 bg-neutral-800 p-2"></textarea>
        </div>
        <div class="flex justify-end gap-2">
          <button type="button" class="rounded border border-neutral-600 px-4 py-1.5" onclick={cancel}>取消</button>
          <button type="button" disabled={busy} class="rounded bg-indigo-600 px-4 py-1.5 disabled:opacity-40"
            onclick={() => void save()}>{busy ? "處理中…" : "儲存"}</button>
        </div>
      </div>
    </div>
  {:else}
    <p class="p-3 text-neutral-500">選擇模型後點擊「載入資訊」。未選取時不讀取模型 Metadata。</p>
  {/if}
</div>
<GalleryPickerModal open={galleryPickerOpen} title="選擇 LoRA 封面" onselect={images => void onGallerySelect(images)}
  onclose={() => galleryPickerOpen = false} />
