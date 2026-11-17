<script lang="ts">
  import {
    searchCivitaiModels,
    downloadModel,
    type CivitaiModel,
  } from "../../utils/api.js";
  // This component is copied to src/lib/addons/lora-browser by install.mjs.
  let query = $state("");
  let searching = $state(false);
  let error = $state("");
  let results = $state<CivitaiModel[]>([]);
  let page = $state(1);
  let hasMore = $state(false);
  let busyId = $state<number | null>(null);
  let status = $state("");
  let currentSearch = $state("");
  let sequence = 0;

  async function search(nextPage = 1) {
    const token = ++sequence;
    searching = true;
    error = "";
    status = "";
    try {
      const response = await searchCivitaiModels({
        query: query.trim() || undefined, type: "LORA", page: nextPage, limit: 20,
      });
      if (token !== sequence) return;
      currentSearch = query.trim();
      results = nextPage === 1 ? response.items : [
        ...results,
        ...response.items.filter((item) => !results.some((prev) => prev.id === item.id)),
      ];
      page = nextPage;
      hasMore = response.items.length > 0
        && (response.metadata.nextCursor ? false : nextPage < (response.metadata.totalPages ?? 1));
    } catch (e) {
      if (token === sequence) error = e instanceof Error ? e.message : String(e);
    } finally {
      if (token === sequence) searching = false;
    }
  }

  async function install(item: CivitaiModel) {
    const version = item.modelVersions[0];
    const file = version?.files.find((f) => f.name.toLowerCase().endsWith(".safetensors"));
    if (!file?.downloadUrl) {
      error = "這個版本沒有可下載的 safetensors 檔案。";
      return;
    }
    if (!confirm(`下載 LoRA「${item.name}」至本地模型目錄？\n檔案：${file.name}`)) return;
    busyId = item.id;
    error = "";
    status = "";
    try {
      await downloadModel(file.downloadUrl, "loras", file.name);
      status = `已送出下載：${file.name}。完成後請在「本地LORA」按重新整理。`;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      busyId = null;
    }
  }
</script>

<div class="space-y-2 text-[11px]">
  <p class="text-neutral-400">CivitAI 外部 LoRA 搜尋</p>
  <form class="flex items-center gap-1" onsubmit={(event) => { event.preventDefault(); void search(); }}>
    <input class="min-w-0 flex-1 rounded border border-neutral-700 bg-neutral-800 px-2 py-1.5 text-neutral-100"
      type="search" bind:value={query} placeholder="搜尋 CivitAI LoRA 名稱" aria-label="搜尋外部 LoRA" />
    <button type="submit" disabled={searching} class="rounded border border-neutral-600 px-3 py-1.5 hover:border-indigo-500 disabled:opacity-50">
      {searching ? "搜尋中…" : "搜尋"}
    </button>
  </form>
  {#if error}<p class="text-amber-300 break-all" role="alert">{error}</p>{/if}
  {#if status}<p class="text-emerald-300">{status}</p>{/if}
  {#if results.length > 0}
    <div class="max-h-52 overflow-y-auto space-y-1 rounded border border-neutral-800 p-1">
      {#each results as item (item.id)}
        <div class="flex items-center gap-2 border-b border-neutral-800 px-1 py-1">
          {#if item.modelVersions[0]?.images?.[0]?.url}
            <img src={item.modelVersions[0].images[0].url} alt="" loading="lazy" class="h-10 w-10 shrink-0 rounded object-cover" />
          {:else}
            <div class="h-10 w-10 shrink-0 rounded bg-neutral-800"></div>
          {/if}
          <div class="min-w-0 flex-1">
            <p class="truncate text-neutral-200" title={item.name}>{item.name}</p>
            <p class="truncate text-neutral-500">{item.modelVersions[0]?.baseModel ?? "底模未提供"} · {item.creator?.username ?? "作者未提供"}</p>
          </div>
          <a class="shrink-0 text-indigo-300 hover:underline" href="https://civitai.com/models/{item.id}" target="_blank" rel="noopener noreferrer">詳情</a>
          <button type="button" disabled={busyId !== null}
            class="shrink-0 rounded border border-neutral-700 px-2 py-1 hover:border-indigo-500 disabled:opacity-40"
            onclick={() => void install(item)}>{busyId === item.id ? "處理中…" : "下載"}</button>
        </div>
      {/each}
    </div>
    {#if hasMore}<button type="button" disabled={searching} onclick={() => void search(page + 1)} class="text-indigo-300 hover:underline">載入更多</button>{/if}
  {:else if currentSearch && !searching && !error}
    <p class="text-neutral-500">沒有搜尋結果。</p>
  {/if}
</div>
