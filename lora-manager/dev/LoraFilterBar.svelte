<script lang="ts">
  import { onMount } from "svelte";
  import type { LoraFilter, LoraGame } from "./loraCategories.js";

  interface Props {
    activeTab: LoraFilter | "";
    gameFilter: LoraGame | "";
    games: LoraGame[];
  }

  let { activeTab = $bindable(), gameFilter = $bindable(), games = [] }: Props = $props();

  const STORAGE_KEY = "mooshieui.plus.localLoraFilters.split.v1";
  const MIN_HEIGHT = 36;
  const MAX_HEIGHT = 260;
  const DEFAULT_HEIGHT = 43;
  const DEFAULT_LEFT_PERCENT = 64;
  const tabs: { value: LoraFilter; label: string }[] = [
    { value: "all", label: "全部" },
    { value: "character", label: "角色" },
    { value: "style", label: "風格" },
    { value: "effect", label: "效果" },
    { value: "other", label: "其他" },
  ];

  let panel = $state<HTMLDivElement>();
  let leftPercent = $state(DEFAULT_LEFT_PERCENT);
  let panelHeight = $state(DEFAULT_HEIGHT);
  let dragging = $state<"horizontal" | "vertical" | null>(null);

  onMount(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "{}");
      if (typeof saved.leftPercent === "number" && Number.isFinite(saved.leftPercent)) {
        leftPercent = Math.max(10, Math.min(85, saved.leftPercent));
      }
      if (typeof saved.panelHeight === "number" && Number.isFinite(saved.panelHeight)) {
        panelHeight = Math.max(MIN_HEIGHT, Math.min(MAX_HEIGHT, saved.panelHeight));
      }
    } catch {
      // Invalid optional layout preferences do not block the selector.
    }
  });

  function storeLayout() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ leftPercent, panelHeight }));
    } catch {
      // Dragging remains available even if preferences cannot be persisted.
    }
  }

  function splitLimits(width: number) {
    const leftMin = Math.min(250, width * 0.48);
    const rightMin = Math.min(195, width * 0.34);
    return {
      min: (leftMin / Math.max(width, 1)) * 100,
      max: ((width - rightMin - 8) / Math.max(width, 1)) * 100,
    };
  }

  function moveDivider(event: PointerEvent, direction: "horizontal" | "vertical") {
    if (!panel || dragging !== direction) return;
    const box = panel.getBoundingClientRect();
    if (direction === "vertical") {
      const limits = splitLimits(box.width);
      leftPercent = Math.max(limits.min, Math.min(limits.max, ((event.clientX - box.left) / box.width) * 100));
    } else {
      panelHeight = Math.max(MIN_HEIGHT, Math.min(MAX_HEIGHT, event.clientY - box.top));
    }
  }

  function startDivider(event: PointerEvent, direction: "horizontal" | "vertical") {
    if (event.button !== 0) return;
    dragging = direction;
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
    event.preventDefault();
  }

  function endDivider(event: PointerEvent) {
    const element = event.currentTarget as HTMLElement;
    if (element.hasPointerCapture(event.pointerId)) element.releasePointerCapture(event.pointerId);
    dragging = null;
    storeLayout();
  }

  function moveByKeyboard(event: KeyboardEvent, direction: "horizontal" | "vertical") {
    if (event.key === "Home") {
      if (direction === "vertical") leftPercent = splitLimits(panel?.clientWidth ?? 900).min;
      else panelHeight = MIN_HEIGHT;
    } else if (event.key === "End") {
      if (direction === "vertical") leftPercent = splitLimits(panel?.clientWidth ?? 900).max;
      else panelHeight = MAX_HEIGHT;
    } else if (direction === "vertical" && (event.key === "ArrowLeft" || event.key === "ArrowRight")) {
      leftPercent += event.key === "ArrowLeft" ? -2 : 2;
      const limits = splitLimits(panel?.clientWidth ?? 900);
      leftPercent = Math.max(limits.min, Math.min(limits.max, leftPercent));
    } else if (direction === "horizontal" && (event.key === "ArrowUp" || event.key === "ArrowDown")) {
      panelHeight = Math.max(MIN_HEIGHT, Math.min(MAX_HEIGHT, panelHeight + (event.key === "ArrowUp" ? -10 : 10)));
    } else {
      return;
    }
    event.preventDefault();
    storeLayout();
  }

  function resetLayout() {
    leftPercent = DEFAULT_LEFT_PERCENT;
    panelHeight = DEFAULT_HEIGHT;
    storeLayout();
  }

  function chooseType(value: LoraFilter) {
    activeTab = value;
    gameFilter = "";
  }
</script>

<div class="shrink-0 px-2 pt-1.5" aria-label="LoRA 分類與資料夾篩選">
  <div bind:this={panel} class="min-w-0">
    <div class="grid min-w-0 overflow-hidden"
      style:height={panelHeight + "px"}
      style:grid-template-columns={`minmax(0, ${leftPercent}%) 8px minmax(0, 1fr)`}>
      <div class="min-w-0 overflow-x-auto overflow-y-auto overscroll-contain pr-1" aria-label="LoRA 類型">
        <div class="flex w-max min-w-full flex-nowrap items-center gap-1 py-0.5" role="group" aria-label="LoRA 類型">
          {#each tabs as tab (tab.value)}
            <button type="button" onclick={() => chooseType(tab.value)}
              aria-pressed={activeTab === tab.value}
              class="shrink-0 rounded-md px-2 py-1 text-[11px] border transition-colors {activeTab === tab.value ? 'border-indigo-500/70 bg-indigo-500/20 text-indigo-200' : 'border-neutral-700 text-neutral-400 hover:text-neutral-200 hover:border-neutral-500'}">
              {tab.label}
            </button>
          {/each}
        </div>
      </div>

      <div role="separator" tabindex="0" aria-label="調整分類與資料夾寬度" aria-orientation="vertical"
        aria-valuemin={Math.round(splitLimits(panel?.clientWidth || 900).min)}
        aria-valuemax={Math.round(splitLimits(panel?.clientWidth || 900).max)}
        aria-valuenow={Math.round(leftPercent)}
        title="左右拖曳調整寬度，雙擊恢復預設"
        class="group z-10 flex h-full w-2 cursor-col-resize touch-none items-stretch justify-center rounded outline-none focus-visible:bg-neutral-500/40"
        onpointerdown={(event) => startDivider(event, "vertical")}
        onpointermove={(event) => moveDivider(event, "vertical")}
        onpointerup={endDivider} onpointercancel={endDivider}
        onkeydown={(event) => moveByKeyboard(event, "vertical")} ondblclick={resetLayout}>
        <div class="h-full w-px bg-neutral-400/55 transition-colors group-hover:bg-neutral-300"></div>
      </div>

      <div class="min-w-0 overflow-x-auto overflow-y-auto overscroll-contain pl-2" aria-label="LoRA 資料夾">
        <div class="flex w-max min-w-full flex-nowrap items-center gap-1.5 py-0.5 text-[11px] text-neutral-400">
          <button type="button" disabled={!activeTab} onclick={() => gameFilter = "all"}
            aria-pressed={gameFilter === "all"}
            class="shrink-0 rounded border px-2 py-1 disabled:opacity-40 {gameFilter === 'all' ? 'border-indigo-500/70 bg-indigo-500/20 text-indigo-200' : 'border-neutral-700 text-neutral-300 hover:border-neutral-500'}">
            全選資料夾
          </button>
          <label for="plus-lora-folder" class="shrink-0">資料夾</label>
          <select id="plus-lora-folder" bind:value={gameFilter} disabled={!activeTab}
            class="min-w-32 max-w-48 rounded border border-neutral-700 bg-neutral-800 px-1.5 py-1 text-neutral-200 disabled:opacity-40">
            <option value="">請選擇資料夾</option>
            <option value="all">全部資料夾</option>
            {#each games as game (game)}
              <option value={game}>{game}</option>
            {/each}
          </select>
        </div>
      </div>
    </div>

    <div role="separator" tabindex="0" aria-label="調整分類區域高度" aria-orientation="horizontal"
      aria-valuemin={MIN_HEIGHT} aria-valuemax={MAX_HEIGHT} aria-valuenow={Math.round(panelHeight)}
      title="上下拖曳調整高度，雙擊恢復預設"
      class="group flex h-2 w-full cursor-row-resize touch-none items-center justify-center outline-none focus-visible:bg-neutral-500/40"
      onpointerdown={(event) => startDivider(event, "horizontal")}
      onpointermove={(event) => moveDivider(event, "horizontal")}
      onpointerup={endDivider} onpointercancel={endDivider}
      onkeydown={(event) => moveByKeyboard(event, "horizontal")} ondblclick={resetLayout}>
      <div class="h-px w-full bg-neutral-400/40 transition-colors group-hover:bg-neutral-300"></div>
    </div>
  </div>
</div>
