<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import Konva from "konva";
  import GalleryPickerModal from "../gallery/GalleryPickerModal.svelte";
  import { loadOutputImageForGenerationInput } from "../../utils/galleryActions.js";
  import { saveToGalleryBytes } from "../../utils/api.js";
  import { gallery } from "../../stores/gallery.svelte.js";
  import type { OutputImage } from "../../types/index.js";

  type Layout = "single" | "2x2" | "1x4" | "4x1";
  type BubbleStyle = "round" | "rect" | "thought" | "shout" | "caption";
  type Panel = { src: string | null; zoom: number; dx: number; dy: number };
  type Bubble = { id: number; x: number; y: number; w: number; h: number; text: string; style: BubbleStyle; fontSize: number; tail: "left" | "right" | "none" };
  type Draft = { version: number; layout: Layout; panels: Panel[]; bubbles: Bubble[] };
  const sizes: Record<Layout, { w: number; h: number; cols: number; rows: number }> = {
    single: { w: 1100, h: 760, cols: 1, rows: 1 },
    "2x2": { w: 1100, h: 1100, cols: 2, rows: 2 },
    "1x4": { w: 1800, h: 480, cols: 4, rows: 1 },
    "4x1": { w: 700, h: 2000, cols: 1, rows: 4 },
  };
  const layouts: { id: Layout; label: string }[] = [
    { id: "single", label: "單張對話" }, { id: "2x2", label: "2 × 2 四格" },
    { id: "1x4", label: "1 × 4 橫式" }, { id: "4x1", label: "4 × 1 直式" },
  ];
  const styles: { id: BubbleStyle; label: string }[] = [
    { id: "round", label: "一般對話" }, { id: "rect", label: "方形對話" },
    { id: "thought", label: "思考" }, { id: "shout", label: "強調" },
    { id: "caption", label: "旁白" },
  ];
  const emptyPanel = (): Panel => ({ src: null, zoom: 1, dx: 0, dy: 0 });
  let layout = $state<Layout>("2x2");
  let panels = $state<Panel[]>(Array.from({ length: 4 }, emptyPanel));
  let bubbles = $state<Bubble[]>([]);
  let panelIndex = $state(0);
  let bubbleId = $state<number | null>(null);
  let galleryOpen = $state(false);
  let status = $state("");
  let loading = $state(false);
  let viewWidth = $state(700);
  let viewHeight = $state(510);
  let stageHost: HTMLDivElement;
  let viewport: HTMLDivElement;
  let stage: Konva.Stage | null = null;
  let layer: Konva.Layer | null = null;
  let resizeObserver: ResizeObserver | null = null;
  let nextId = 1;
  const cache = new Map<string, HTMLImageElement>();
  const spec = $derived(sizes[layout]);
  const scale = $derived(Math.min(1, Math.max(0.15, Math.min((viewWidth - 24) / spec.w, (viewHeight - 24) / spec.h))));
  const chosenBubble = $derived(bubbles.find(b => b.id === bubbleId) ?? null);
  const chosenPanel = $derived(panels[panelIndex] ?? emptyPanel());

  function rectFor(i: number) {
    const margin = 18, gap = 14;
    const w = (spec.w - margin * 2 - gap * (spec.cols - 1)) / spec.cols;
    const h = (spec.h - margin * 2 - gap * (spec.rows - 1)) / spec.rows;
    return { x: margin + (i % spec.cols) * (w + gap), y: margin + Math.floor(i / spec.cols) * (h + gap), w, h };
  }
  function getImage(src: string): HTMLImageElement | null {
    const existing = cache.get(src);
    if (existing) return existing.complete && existing.naturalWidth > 0 ? existing : null;
    const img = new Image();
    cache.set(src, img);
    img.onload = () => draw();
    img.onerror = () => { cache.delete(src); status = "圖片解碼失敗，請更換圖片"; };
    img.src = src;
    return null;
  }
  function clamp(n: number, min: number, max: number) { return Math.max(min, Math.min(max, n)); }
  function updatePanel(patch: Partial<Panel>) {
    panels = panels.map((p, i) => i === panelIndex ? { ...p, ...patch } : p);
  }
  function updateBubble(patch: Partial<Bubble>) {
    bubbles = bubbles.map(b => b.id === bubbleId ? { ...b, ...patch } : b);
  }
  function changeLayout(value: Layout) {
    if (layout === value) return;
    if (bubbles.length && !window.confirm("變更版型會清空目前的對話框，圖片會依原順序保留。確定變更？")) return;
    layout = value;
    panels = Array.from({ length: sizes[value].cols * sizes[value].rows }, (_, i) => panels[i] ?? emptyPanel());
    bubbles = [];
    bubbleId = null;
    panelIndex = Math.min(panelIndex, panels.length - 1);
    status = "";
  }
  function draw(showSelection = true) {
    if (!stage || !layer) return;
    stage.width(spec.w);
    stage.height(spec.h);
    layer.destroyChildren();
    layer.add(new Konva.Rect({ width: spec.w, height: spec.h, fill: "#ffffff", listening: false }));
    panels.forEach((p, i) => {
      const r = rectFor(i);
      const selected = showSelection && panelIndex === i && bubbleId === null;
      const group = new Konva.Group({ x: r.x, y: r.y, clipX: 0, clipY: 0, clipWidth: r.w, clipHeight: r.h });
      layer!.add(group);
      group.add(new Konva.Rect({ x: 0, y: 0, width: r.w, height: r.h, fill: showSelection ? "#e5e7eb" : "#ffffff" }));
      if (p.src) {
        const img = getImage(p.src);
        if (img) {
          const fitted = Math.max(r.w / img.naturalWidth, r.h / img.naturalHeight) * p.zoom;
          const iw = img.naturalWidth * fitted, ih = img.naturalHeight * fitted;
          const cx = (r.w - iw) / 2, cy = (r.h - ih) / 2;
          const node = new Konva.Image({
            image: img, x: clamp(cx + p.dx, r.w - iw, 0), y: clamp(cy + p.dy, r.h - ih, 0),
            width: iw, height: ih, draggable: true,
          });
          node.on("dragmove", () => { node.position({ x: clamp(node.x(), r.w - iw, 0), y: clamp(node.y(), r.h - ih, 0) }); });
          node.on("dragend", () => {
            panelIndex = i; bubbleId = null;
            panels = panels.map((item, k) => k === i ? { ...item, dx: node.x() - cx, dy: node.y() - cy } : item);
          });
          node.on("click tap", () => { panelIndex = i; bubbleId = null; });
          group.add(node);
        }
      } else if (showSelection) {
        group.add(new Konva.Text({
          x: 0, y: r.h / 2 - 26, width: r.w, text: "第 " + (i + 1) + " 格\n從左側載入圖片",
          align: "center", fontSize: Math.max(15, Math.min(25, r.w / 15)), lineHeight: 1.5, fill: "#64748b",
        }));
      }
      // Panel outline stays above images but does not intercept dragging.
      group.add(new Konva.Rect({
        x: 0, y: 0, width: r.w, height: r.h, stroke: selected ? "#6366f1" : "#111827",
        strokeWidth: selected ? 5 : 3, listening: false,
      }));
      group.on("click tap", e => {
        if (e.target.getClassName() === "Rect" || e.target.getClassName() === "Text") {
          panelIndex = i; bubbleId = null;
        }
      });
    });
    bubbles.forEach((b) => {
      const g = new Konva.Group({ x: b.x, y: b.y, draggable: true });
      const chosen = showSelection && b.id === bubbleId;
      const common = { fill: b.style === "caption" ? "#fff8e7" : "#ffffff", stroke: chosen ? "#4f46e5" : "#111827", strokeWidth: chosen ? 5 : 3 };
      if (b.style === "round" || b.style === "thought") {
        g.add(new Konva.Ellipse({ x: b.w / 2, y: b.h / 2, radiusX: b.w / 2, radiusY: b.h / 2, ...common }));
      } else if (b.style === "shout") {
        g.add(new Konva.Star({ x: b.w / 2, y: b.h / 2, numPoints: 11, innerRadius: Math.min(b.w, b.h) * 0.37, outerRadius: Math.min(b.w, b.h) * 0.63, ...common }));
      } else {
        g.add(new Konva.Rect({ width: b.w, height: b.h, cornerRadius: b.style === "rect" ? 16 : 2, ...common }));
      }
      if (b.style !== "caption" && b.tail !== "none") {
        const tx = b.tail === "left" ? b.w * 0.3 : b.w * 0.7;
        g.add(new Konva.Line({ points: [tx - 16, b.h - 15, tx + (b.tail === "left" ? -42 : 42), b.h + 40, tx + 18, b.h - 15], closed: true, fill: "#fff", stroke: "#111827", strokeWidth: 3 }));
      }
      if (b.style === "thought") {
        g.add(new Konva.Circle({ x: b.w * 0.25, y: b.h + 24, radius: 10, fill: "#fff", stroke: "#111827", strokeWidth: 2 }));
        g.add(new Konva.Circle({ x: b.w * 0.16, y: b.h + 40, radius: 5, fill: "#fff", stroke: "#111827", strokeWidth: 2 }));
      }
      g.add(new Konva.Text({
        x: b.w * 0.12, y: b.h * 0.11, width: b.w * 0.76, height: b.h * 0.78,
        text: b.text, align: "center", verticalAlign: "middle", wrap: "char",
        fontSize: b.fontSize, fontFamily: "Microsoft JhengHei, Noto Sans CJK TC, sans-serif",
        fill: "#111827", lineHeight: 1.15,
      }));
      g.on("click tap", () => { bubbleId = b.id; });
      g.on("dragend", () => {
        bubbleId = b.id;
        bubbles = bubbles.map(item => item.id === b.id ? {
          ...item, x: clamp(g.x(), 0, Math.max(0, spec.w - item.w)),
          y: clamp(g.y(), 0, Math.max(0, spec.h - item.h - 42)),
        } : item);
      });
      layer!.add(g);
    });
    layer.draw();
  }
  $effect(() => {
    void layout; void panels; void bubbles; void panelIndex; void bubbleId;
    draw();
  });
  onMount(() => {
    stage = new Konva.Stage({ container: stageHost, width: spec.w, height: spec.h });
    layer = new Konva.Layer();
    stage.add(layer);
    resizeObserver = new ResizeObserver(() => {
      if (!viewport) return;
      if (viewport.clientWidth > 0) viewWidth = viewport.clientWidth;
      if (viewport.clientHeight > 0) viewHeight = viewport.clientHeight;
    });
    resizeObserver.observe(viewport);
    draw();
    void restoreLocalDraft();
  });
  onDestroy(() => { resizeObserver?.disconnect(); stage?.destroy(); stage = null; cache.clear(); });

  async function blobDataUrl(blob: Blob): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result));
      reader.onerror = () => reject(new Error("檔案讀取失敗"));
      reader.readAsDataURL(blob);
    });
  }
  async function assignImage(blob: Blob) {
    if (!blob.type.startsWith("image/")) throw new Error("請選擇圖片檔案");
    if (blob.size > 30 * 1024 * 1024) throw new Error("單張圖片不得超過 30MB");
    const src = await blobDataUrl(blob);
    const img = new Image();
    await new Promise<void>((resolve, reject) => { img.onload = () => resolve(); img.onerror = () => reject(new Error("不支援的圖片")); img.src = src; });
    updatePanel({ src, zoom: 1, dx: 0, dy: 0 });
    cache.set(src, img);
    status = "圖片已載入第 " + (panelIndex + 1) + " 格";
  }
  async function pickLocal(file: File | undefined) {
    if (!file) return;
    loading = true;
    try { await assignImage(file); } catch (e) { status = String(e); }
    finally { loading = false; }
  }
  async function pickGallery(images: OutputImage[]) {
    const image = images[0];
    if (!image) return;
    galleryOpen = false; loading = true;
    try {
      const loaded = await loadOutputImageForGenerationInput(image);
      await assignImage(new Blob([new Uint8Array(loaded.bytes)], { type: "image/png" }));
    } catch (e) { status = "圖庫圖片載入失敗：" + String(e); }
    finally { loading = false; }
  }
  function addBubble(style: BubbleStyle) {
    const r = rectFor(panelIndex);
    const w = Math.min(360, r.w * 0.75), h = Math.min(180, r.h * 0.36);
    const id = nextId++;
    bubbles = [...bubbles, {
      id, x: r.x + Math.max(0, (r.w - w) / 2), y: r.y + 16, w, h,
      text: "輸入對話文字", style, fontSize: 35, tail: style === "caption" ? "none" : "left",
    }];
    bubbleId = id;
  }
  function deleteBubble() {
    if (bubbleId === null) return;
    bubbles = bubbles.filter(b => b.id !== bubbleId);
    bubbleId = null;
  }
  function project(): Draft { return { version: 1, layout, panels: panels.map(p => ({ ...p })), bubbles: bubbles.map(b => ({ ...b })) }; }
  function readProject(raw: unknown): Draft {
    if (!raw || typeof raw !== "object") throw new Error("草稿格式不正確");
    const d = raw as Draft;
    if (d.version !== 1 || !(d.layout in sizes) || !Array.isArray(d.panels) || !Array.isArray(d.bubbles)) throw new Error("不支援的漫畫草稿");
    if (d.panels.length !== sizes[d.layout].cols * sizes[d.layout].rows || d.bubbles.length > 300) throw new Error("草稿圖層數量不正確");
    for (const p of d.panels) {
      if (p.src !== null && (typeof p.src !== "string" || !/^data:image\/(png|jpeg|webp);base64,/.test(p.src))) throw new Error("草稿圖片格式不支援");
      if (![p.zoom, p.dx, p.dy].every(Number.isFinite)) throw new Error("草稿座標不正確");
    }
    for (const b of d.bubbles) {
      if (!styles.some(s => s.id === b.style) || typeof b.text !== "string" || b.text.length > 5000 || ![b.x,b.y,b.w,b.h,b.fontSize,b.id].every(Number.isFinite) || b.w < 20 || b.h < 20 || !["left","right","none"].includes(b.tail)) throw new Error("草稿對話框格式不正確");
    }
    return d;
  }
  function applyDraft(d: Draft) {
    layout = d.layout;
    panels = d.panels;
    bubbles = d.bubbles;
    nextId = Math.max(1, ...bubbles.map(b => b.id + 1));
    panelIndex = 0; bubbleId = null;
    cache.clear();
  }
  function openDb(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("mooshieui-comic-v1", 1);
      request.onupgradeneeded = () => request.result.createObjectStore("drafts");
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
  async function saveLocalDraft() {
    try {
      const db = await openDb();
      await new Promise<void>((resolve, reject) => {
        const tx = db.transaction("drafts", "readwrite");
        tx.objectStore("drafts").put(project(), "latest");
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      });
      db.close();
      status = "草稿已儲存於目前 MooshieUI 的本機資料庫";
    } catch (e) { status = "草稿儲存失敗：" + String(e); }
  }
  async function restoreLocalDraft() {
    try {
      const db = await openDb();
      const raw = await new Promise<unknown>((resolve, reject) => {
        const request = db.transaction("drafts", "readonly").objectStore("drafts").get("latest");
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      db.close();
      if (raw) { applyDraft(readProject(raw)); status = "已還原上次儲存的漫畫草稿"; }
    } catch (e) { status = "無法還原本機草稿：" + String(e); }
  }
  function download(blob: Blob, filename: string) {
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url; anchor.download = filename;
    document.body.appendChild(anchor); anchor.click(); anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  async function exportProject() {
    try {
      const json = JSON.stringify(project());
      const filename = "mooshie-comic-project.json";
      if (typeof window !== "undefined" && "__TAURI_INTERNALS__" in window) {
        const { save } = await import("@tauri-apps/plugin-dialog");
        const { writeTextFile } = await import("@tauri-apps/plugin-fs");
        const path = await save({ defaultPath: filename, filters: [{ name: "JSON", extensions: ["json"] }] });
        if (!path) return;
        await writeTextFile(path, json);
        status = "草稿已匯出至：" + path;
      } else {
        download(new Blob([json], { type: "application/json" }), filename);
        status = "已啟動草稿 JSON 下載";
      }
    } catch (e) {
      status = "草稿匯出失敗：" + String(e);
    }
  }
  async function importProject(file: File | undefined) {
    if (!file) return;
    try {
      if (file.size > 150 * 1024 * 1024) throw new Error("草稿檔案過大");
      applyDraft(readProject(JSON.parse(await file.text())));
      status = "已匯入漫畫草稿";
    } catch (e) { status = "草稿匯入失敗：" + String(e); }
  }
  function renderPng(): string {
    if (!stage) throw new Error("漫畫畫布尚未載入");
    // Export without selection highlights or placeholder instructions.
    draw(false);
    try { return stage.toDataURL({ mimeType: "image/png", pixelRatio: 1 }); }
    finally { draw(); }
  }
  function exportPng() {
    try {
      const src = renderPng();
      const anchor = document.createElement("a");
      anchor.href = src; anchor.download = "mooshie-comic.png";
      document.body.appendChild(anchor); anchor.click(); anchor.remove();
      status = "已匯出 PNG（" + spec.w + " × " + spec.h + "）";
    } catch (e) { status = "PNG 匯出失敗：" + String(e); }
  }
  async function saveGallery() {
    if (loading) return;
    loading = true;
    try {
      const imageBlob = await (await fetch(renderPng())).blob();
      const bytes = Array.from(new Uint8Array(await imageBlob.arrayBuffer()));
      const name = "comic-" + Date.now() + ".png";
      const saved = await saveToGalleryBytes(bytes, name, "comic-" + Date.now());
      await gallery.addPersistedImage(saved);
      status = "已儲存到 MooshieUI 圖庫：" + name;
    } catch (e) { status = "儲存圖庫失敗：" + String(e); }
    finally { loading = false; }
  }
</script>

<section class="flex h-full min-h-[440px] flex-col gap-3 text-neutral-200">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div><h3 class="font-semibold">40｜漫畫排版與對話框</h3><p class="text-xs text-neutral-400">先選版型，逐格放圖，再編輯對話。完全不修改生圖參數。</p></div>
    <div class="flex flex-wrap gap-2">
      <button class="rounded border border-neutral-600 px-3 py-2 text-xs hover:bg-neutral-800" onclick={saveLocalDraft}>儲存草稿</button>
      <button class="rounded border border-neutral-600 px-3 py-2 text-xs hover:bg-neutral-800" onclick={exportProject}>匯出草稿 JSON</button>
      <label class="cursor-pointer rounded border border-neutral-600 px-3 py-2 text-xs hover:bg-neutral-800">載入草稿<input class="hidden" type="file" accept=".json,application/json" onchange={e => { void importProject(e.currentTarget.files?.[0]); e.currentTarget.value = ""; }}/></label>
      <button class="rounded border border-indigo-500 px-3 py-2 text-xs font-semibold text-indigo-200 hover:bg-indigo-950/40" onclick={() => { void saveGallery(); }} disabled={loading}>儲存至圖庫</button>
      <button class="rounded bg-indigo-600 px-4 py-2 text-xs font-semibold text-white hover:bg-indigo-500" onclick={exportPng}>匯出 PNG</button>
    </div>
  </header>
  <div class="grid min-h-0 flex-1 grid-cols-1 gap-3 xl:grid-cols-[230px_minmax(0,1fr)_240px]">
    <aside class="space-y-4 rounded-xl border border-neutral-700 bg-neutral-900/70 p-3 text-xs">
      <div class="space-y-2"><label for="comic-layout" class="font-semibold">01　漫畫版型</label>
        <select id="comic-layout" class="w-full rounded border border-neutral-600 bg-neutral-800 p-2" value={layout} onchange={e => changeLayout(e.currentTarget.value as Layout)}>
          {#each layouts as item}<option value={item.id}>{item.label}</option>{/each}
        </select>
      </div>
      <div class="space-y-2">
        <p class="font-semibold">02　選擇格子</p>
        <div class="grid grid-cols-4 gap-1">{#each panels as p,i}
          <button class="rounded border p-2 {panelIndex===i?'border-indigo-400 bg-indigo-600/30':'border-neutral-600 bg-neutral-800'}" onclick={() => { panelIndex=i; bubbleId=null; }}>{i+1}{p.src?' ✓':''}</button>
        {/each}</div>
        <button class="w-full rounded border border-neutral-600 bg-neutral-800 p-2 hover:bg-neutral-700" onclick={() => galleryOpen=true} disabled={loading}>從 MooshieUI 圖庫選擇</button>
        <label class="block cursor-pointer rounded border border-neutral-600 bg-neutral-800 p-2 text-center hover:bg-neutral-700">本地匯入圖片
          <input class="hidden" type="file" accept="image/png,image/jpeg,image/webp" onchange={e => { void pickLocal(e.currentTarget.files?.[0]); e.currentTarget.value = ""; }} />
        </label>
        {#if chosenPanel.src}
          <label class="block">圖片縮放：{Math.round(chosenPanel.zoom*100)}%
            <input type="range" min="1" max="3" step="0.05" value={chosenPanel.zoom} oninput={e => updatePanel({zoom:Number(e.currentTarget.value),dx:0,dy:0})} class="mt-1 w-full accent-indigo-500"/>
          </label>
          <button class="w-full rounded border border-red-800 p-2 text-red-300" onclick={() => updatePanel(emptyPanel())}>移除第 {panelIndex+1} 格圖片</button>
          <p class="text-neutral-500">直接拖曳畫布中的圖片可調整裁切位置。</p>
        {/if}
      </div>
      <div class="space-y-2">
        <p class="font-semibold">03　插入對話框</p>
        <div class="grid grid-cols-2 gap-1">{#each styles as item}
          <button class="rounded border border-neutral-600 bg-neutral-800 px-1 py-2 hover:bg-neutral-700" onclick={() => addBubble(item.id)}>{item.label}</button>
        {/each}</div>
      </div>
    </aside>
    <div bind:this={viewport} class="relative min-h-[420px] min-w-0 overflow-auto rounded-xl border border-neutral-700 bg-neutral-950 p-3">
      <div class="mx-auto" style:width={(spec.w*scale)+'px'} style:height={(spec.h*scale)+'px'}>
        <div bind:this={stageHost} class="origin-top-left shadow-lg" style:width={spec.w+'px'} style:height={spec.h+'px'} style:transform={'scale('+scale+')'}></div>
      </div>
    </div>
    <aside class="space-y-3 rounded-xl border border-neutral-700 bg-neutral-900/70 p-3 text-xs">
      <p class="font-semibold">04　文字與對話框編輯</p>
      {#if chosenBubble}
        <label class="block space-y-1">內容
          <textarea class="h-28 w-full rounded border border-neutral-600 bg-neutral-800 p-2" value={chosenBubble.text} oninput={e => updateBubble({text:e.currentTarget.value})}></textarea>
        </label>
        <label class="block space-y-1">樣式
          <select class="w-full rounded border border-neutral-600 bg-neutral-800 p-2" value={chosenBubble.style} onchange={e => updateBubble({style:e.currentTarget.value as BubbleStyle})}>
            {#each styles as item}<option value={item.id}>{item.label}</option>{/each}
          </select>
        </label>
        <label class="block">字體大小：{chosenBubble.fontSize}
          <input type="range" min="16" max="72" value={chosenBubble.fontSize} oninput={e => updateBubble({fontSize:Number(e.currentTarget.value)})} class="w-full accent-indigo-500"/>
        </label>
        <label class="block">寬度：{Math.round(chosenBubble.w)}
          <input type="range" min="120" max="600" value={chosenBubble.w} oninput={e => updateBubble({w:Number(e.currentTarget.value)})} class="w-full accent-indigo-500"/>
        </label>
        <label class="block">高度：{Math.round(chosenBubble.h)}
          <input type="range" min="90" max="360" value={chosenBubble.h} oninput={e => updateBubble({h:Number(e.currentTarget.value)})} class="w-full accent-indigo-500"/>
        </label>
        <label class="block space-y-1">尾巴方向
          <select class="w-full rounded border border-neutral-600 bg-neutral-800 p-2" value={chosenBubble.tail} onchange={e => updateBubble({tail:e.currentTarget.value as Bubble["tail"]})}>
            <option value="left">左下</option><option value="right">右下</option><option value="none">不顯示</option>
          </select>
        </label>
        <button class="w-full rounded border border-red-700 p-2 text-red-300 hover:bg-red-950/40" onclick={deleteBubble}>刪除此對話框</button>
        <p class="text-neutral-500">直接拖曳對話框移動位置；可在同一格新增多個。</p>
      {:else}
        <p class="text-neutral-400">在左側選擇對話框樣式後，點選畫布上的對話框即可修改文字。</p>
      {/if}
      <p class="border-t border-neutral-700 pt-3 text-neutral-500">草稿存在此 MooshieUI 執行環境的本機資料庫（IndexedDB，不是 module_data）；可另外匯出包含圖片的 JSON 備份。PNG 可以直接儲存到現有圖庫。</p>
    </aside>
  </div>
  {#if status}<p role="status" class="shrink-0 rounded bg-neutral-800 px-3 py-2 text-xs text-neutral-300">{loading?'讀取中… ':''}{status}</p>{/if}
  <GalleryPickerModal open={galleryOpen} title={"選擇第 "+(panelIndex+1)+" 格的圖片"} onselect={images => { void pickGallery(images); }} onclose={() => galleryOpen=false}/>
</section>
