<script lang="ts">
  import {
    createPosePerson, parseOpenPoseJson, renderPosePng, POSE_LIMBS, POSE_JOINT_LABELS,
    type PosePerson, type PosePreset,
  } from "../../utils/creativePose.js";

  interface Props {
    width: number;
    height: number;
    sourceUrl?: string | null;
    sourceSize?: { width: number; height: number } | null;
    busy?: boolean;
    canApply: boolean;
    availability?: string | null;
    onPickImage: () => void;
    onLocalImage: (file: File) => void;
    onDetect: () => Promise<string>;
    onApply: (bytes: number[]) => Promise<void>;
  }

  let {
    width, height, sourceUrl = null, sourceSize = null, busy = false, canApply, availability = null,
    onPickImage, onLocalImage, onDetect, onApply,
  }: Props = $props();
  let people = $state<PosePerson[]>([createPosePerson(1)]);
  let activeId = $state(1);
  let preset = $state<PosePreset>("standing");
  let zoom = $state(1);
  let panX = $state(50);
  let panY = $state(50);
  let referenceVisible = $state(true);
  let applying = $state(false);
  let detecting = $state(false);
  let message = $state<string | null>(null);
  let svg: SVGSVGElement;
  let drag = $state<{ personId: number; jointIndex: number } | null>(null);
  let nextId = 2;

  const activePerson = $derived(people.find(p => p.id === activeId) ?? null);
  const viewWidth = $derived(width / zoom);
  const viewHeight = $derived(height / zoom);
  const viewX = $derived((width - viewWidth) * panX / 100);
  const viewY = $derived((height - viewHeight) * panY / 100);
  const view = $derived(`${viewX} ${viewY} ${viewWidth} ${viewHeight}`);

  function addPerson() {
    if (people.length >= 20) return;
    const id = nextId++;
    const cx = people.length % 2 === 0 ? 0.3 : 0.7;
    people.push(createPosePerson(id, cx, 0.53, preset));
    activeId = id;
    message = null;
  }

  function removePerson(id: number) {
    people = people.filter(p => p.id !== id);
    if (activeId === id) activeId = people[0]?.id ?? 0;
  }

  function setPreset(value: PosePreset) {
    preset = value;
    const current = activePerson;
    if (!current || current.locked) return;
    const neck = current.joints[1];
    const fresh = createPosePerson(current.id, neck.x, neck.y + .23, preset);
    current.joints = fresh.joints;
  }

  function restoreMissingJoints() {
    const current = activePerson;
    if (!current || current.locked) return;
    const neck = current.joints[1];
    const fallback = createPosePerson(current.id, neck.x, neck.y + .23);
    let count = 0;
    for (let i = 0; i < current.joints.length; i++) {
      if (current.joints[i].visible) continue;
      current.joints[i] = { ...fallback.joints[i] };
      count++;
    }
    message = count ? `已用預設站姿補上 ${count} 個未辨識關節（估計位置），可拖曳修正。` : "沒有需要補齊的關節。";
  }

  function shift(dx: number, dy: number) {
    if (!activePerson || activePerson.locked) return;
    for (const point of activePerson.joints) {
      point.x = Math.max(0, Math.min(1, point.x + dx));
      point.y = Math.max(0, Math.min(1, point.y + dy));
    }
  }

  function beginDrag(e: PointerEvent, personId: number, jointIndex: number) {
    const person = people.find(p => p.id === personId);
    if (!person || !person.visible || person.locked) return;
    activeId = personId;
    drag = { personId, jointIndex };
    svg.setPointerCapture(e.pointerId);
    e.preventDefault();
  }

  function moveDrag(e: PointerEvent) {
    if (!drag) return;
    const person = people.find(p => p.id === drag!.personId);
    const matrix = svg.getScreenCTM();
    if (!person || !matrix) return;
    const local = new DOMPoint(e.clientX, e.clientY).matrixTransform(matrix.inverse());
    const point = person.joints[drag.jointIndex];
    point.x = Math.max(0, Math.min(1, local.x / width));
    point.y = Math.max(0, Math.min(1, local.y / height));
  }

  async function importJson(file: File) {
    message = null;
    try {
      const parsed = parseOpenPoseJson(await file.text());
      people = parsed;
      nextId = parsed.length + 1;
      activeId = parsed[0].id;
      message = `已匯入 ${parsed.length} 個人物的真實關節座標，可繼續編輯。`;
    } catch (e) {
      message = e instanceof Error ? e.message : String(e);
    }
  }

  async function detectPhoto() {
    if (!sourceUrl || busy || detecting) return;
    detecting = true;
    message = null;
    try {
      let parsed = parseOpenPoseJson(await onDetect());
      // The photo is displayed with SVG "meet" (letterboxed), not stretched
      // across the generation canvas. Map detected photo-relative keypoints
      // into that same visible rectangle before they become editable joints.
      if (sourceSize?.width && sourceSize.height) {
        const fit = Math.min(width / sourceSize.width, height / sourceSize.height);
        const photoWidth = sourceSize.width * fit;
        const photoHeight = sourceSize.height * fit;
        const left = (width - photoWidth) / 2;
        const top = (height - photoHeight) / 2;
        parsed = parsed.map(person => ({
          ...person,
          joints: person.joints.map(point => ({
            ...point,
            x: (left + point.x * photoWidth) / width,
            y: (top + point.y * photoHeight) / height,
          })),
        }));
      }
      people = parsed;
      nextId = parsed.length + 1;
      activeId = parsed[0].id;
      message = `已從照片辨識 ${parsed.length} 個人物，可逐人拖曳關節調整。`;
    } catch (e) {
      message = e instanceof Error ? e.message : String(e);
    } finally {
      detecting = false;
    }
  }

  async function apply() {
    if (!canApply || busy || applying || detecting || people.every(p => !p.visible)) return;
    applying = true;
    message = null;
    try {
      await onApply(await renderPosePng(people, width, height));
    } catch (e) {
      message = e instanceof Error ? e.message : String(e);
    } finally {
      applying = false;
    }
  }
</script>

<div class="grid grid-cols-1 gap-3 xl:grid-cols-[minmax(0,1fr)_minmax(260px,300px)]">
  <section class="space-y-3 rounded-xl border border-neutral-700 bg-neutral-900/60 p-3">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h3 class="text-sm font-semibold">01　多人骨架畫布</h3>
      <span class="text-xs text-neutral-400">{width} × {height} px</span>
    </div>
    <div class="flex flex-wrap items-center gap-2 text-xs">
      <button class="rounded border border-neutral-600 px-2 py-1.5 hover:bg-neutral-800" onclick={addPerson} disabled={people.length >= 20}>新增人物</button>
      <button class="rounded border border-neutral-600 px-2 py-1.5 hover:bg-neutral-800" onclick={() => setPreset("standing")} disabled={!activePerson || activePerson.locked}>站立</button>
      <button class="rounded border border-neutral-600 px-2 py-1.5 hover:bg-neutral-800" onclick={() => setPreset("arms_up")} disabled={!activePerson || activePerson.locked}>舉手</button>
      <label class="flex items-center gap-1"><input type="checkbox" bind:checked={referenceVisible} /> 顯示參考照片</label>
    </div>
    <div class="mx-auto w-full max-w-[700px] overflow-hidden rounded-lg border border-neutral-700 bg-black" style={`aspect-ratio:${width}/${height}`}>
      <svg bind:this={svg} xmlns="http://www.w3.org/2000/svg" viewBox={view}
        class="h-full w-full touch-none" role="img" aria-label="可編輯的多人骨架畫布"
        onpointermove={moveDrag} onpointerup={() => drag = null} onpointercancel={() => drag = null}>
        <rect x="0" y="0" {width} {height} fill="#000" />
        {#if sourceUrl && referenceVisible}
          <image href={sourceUrl} x="0" y="0" {width} {height} opacity="0.35" preserveAspectRatio="xMidYMid meet" />
        {/if}
        {#each people as person (person.id)}
          {#if person.visible}
            {#each POSE_LIMBS as limb}
              {@const start = person.joints[limb[0]]}
              {@const end = person.joints[limb[1]]}
              {#if start.visible && end.visible}
                <line x1={start.x * width} y1={start.y * height} x2={end.x * width} y2={end.y * height}
                  stroke={limb[2]} stroke-width={Math.max(3, Math.min(width, height) / 52)} stroke-linecap="round"
                  opacity={person.id === activeId ? 1 : 0.65} />
              {/if}
            {/each}
            {#each person.joints as joint, index}
              {#if joint.visible}
                <circle cx={joint.x * width} cy={joint.y * height}
                  r={Math.max(6, Math.min(width, height) / 65) / zoom}
                  fill={person.id === activeId ? "#fff" : "#c6c6c6"}
                  stroke={person.id === activeId ? "#6366f1" : "#222"}
                  stroke-width={Math.max(2, 3 / zoom)}
                  class={person.locked ? "cursor-not-allowed" : "cursor-grab"}
                  onpointerdown={(event) => beginDrag(event, person.id, index)}>
                  <title>{person.name}｜{POSE_JOINT_LABELS[index]}</title>
                </circle>
              {/if}
            {/each}
          {/if}
        {/each}
      </svg>
    </div>
    <div class="grid grid-cols-1 gap-2 text-xs sm:grid-cols-2">
      <label>縮放 {zoom.toFixed(1)} 倍<input class="block w-full accent-indigo-500" type="range" min="1" max="3" step=".25" bind:value={zoom} /></label>
      <div class="flex items-center gap-2">
        <label class="flex-1">水平檢視<input class="w-full accent-indigo-500" type="range" min="0" max="100" step="5" bind:value={panX} disabled={zoom === 1} /></label>
        <label class="flex-1">垂直檢視<input class="w-full accent-indigo-500" type="range" min="0" max="100" step="5" bind:value={panY} disabled={zoom === 1} /></label>
      </div>
    </div>
    <p class="text-xs text-neutral-400">拖曳白色關節點調整姿勢；照片僅作半透明位置參考，不會寫入輸出 PNG。</p>
  </section>

  <div class="space-y-3">
    <section class="space-y-3 rounded-xl border border-neutral-700 bg-neutral-900/60 p-3">
      <h3 class="text-sm font-semibold">02　來源與匯入</h3>
      <button class="rounded border border-neutral-600 px-3 py-1.5 text-xs hover:bg-neutral-800" onclick={onPickImage}>從圖庫選照片</button>
      <label class="block text-xs">本地參考照片
        <input class="mt-1 block w-full text-xs" type="file" accept="image/png,image/jpeg,image/webp"
          onchange={(event) => { const file = event.currentTarget.files?.[0]; if (file) onLocalImage(file); event.currentTarget.value = ""; }} />
      </label>
      <label class="block text-xs">匯入 OpenPose 關節 JSON（COCO-18／BODY-25）
        <input class="mt-1 block w-full text-xs" type="file" accept=".json,application/json"
          onchange={(event) => { const file = event.currentTarget.files?.[0]; if (file) void importJson(file); event.currentTarget.value = ""; }} />
      </label>
      <button class="rounded border border-neutral-600 px-3 py-1.5 text-xs hover:bg-neutral-800 disabled:opacity-40"
        disabled={!sourceUrl || busy || detecting} onclick={detectPhoto}>
        {detecting ? "正在辨識人物關節…" : "從照片辨識可編輯骨架"}
      </button>
      <p class="text-xs text-neutral-400">從照片辨識會將關節對齊等比例顯示的參考圖，沒有拍到的身體部位可選擇補點並手動調整。辨識失敗不會覆蓋目前骨架。</p>
    </section>

    <section class="space-y-2 rounded-xl border border-neutral-700 bg-neutral-900/60 p-3">
      <h3 class="text-sm font-semibold">03　人物清單</h3>
      {#each people as person (person.id)}
        <div class="flex flex-wrap items-center gap-2 rounded-lg border p-2 text-xs {activeId === person.id ? 'border-indigo-500' : 'border-neutral-700'}">
          <button class="min-w-0 flex-1 truncate text-left" onclick={() => activeId = person.id}>{person.name}</button>
          <label><input type="checkbox" bind:checked={person.visible} /> 顯示</label>
          <label><input type="checkbox" bind:checked={person.locked} /> 鎖定</label>
          <button class="text-red-300" title="刪除人物" onclick={() => removePerson(person.id)}>移除</button>
        </div>
      {/each}
      {#if activePerson && activePerson.joints.some(joint => !joint.visible)}
        <div class="space-y-1">
          <button class="rounded border border-amber-700 px-2 py-1 text-xs text-amber-200 hover:bg-amber-950/40"
            onclick={restoreMissingJoints} disabled={activePerson.locked}>補齊未辨識關節（預設位置）</button>
          <p class="text-[11px] text-neutral-500">補上的關節只是可調整的估計位置，不是照片辨識結果。</p>
        </div>
      {/if}
      <div class="flex items-center gap-1 text-xs">
        <span class="mr-1 text-neutral-400">移動選取人物：</span>
        <button class="rounded border border-neutral-600 px-2 py-1" onclick={() => shift(-.03, 0)} disabled={!activePerson || activePerson.locked}>←</button>
        <button class="rounded border border-neutral-600 px-2 py-1" onclick={() => shift(0, -.03)} disabled={!activePerson || activePerson.locked}>↑</button>
        <button class="rounded border border-neutral-600 px-2 py-1" onclick={() => shift(0, .03)} disabled={!activePerson || activePerson.locked}>↓</button>
        <button class="rounded border border-neutral-600 px-2 py-1" onclick={() => shift(.03, 0)} disabled={!activePerson || activePerson.locked}>→</button>
      </div>
    </section>

    <section class="space-y-2 rounded-xl border border-neutral-700 bg-neutral-900/60 p-3">
      <h3 class="text-sm font-semibold">04　交接至原生生圖</h3>
      <p class="text-xs text-neutral-400">輸出黑底彩色骨架 PNG，帶入原生 ControlNet 自訂模式。沿用目前模型、提示詞及其他生成參數，確認後再按「生成」。</p>
      {#if availability}
        <p class="text-xs {canApply ? 'text-neutral-400' : 'text-amber-300'}">{availability}</p>
      {/if}
      {#if message}<p role="status" class="text-xs text-amber-300">{message}</p>{/if}
      <button class="rounded-lg bg-indigo-600 px-3 py-2 text-xs font-semibold text-white disabled:opacity-40"
        disabled={!canApply || busy || applying || detecting || !people.some(p => p.visible)}
        onclick={apply}>{busy || applying ? "準備中…" : "帶入原生 OpenPose ControlNet"}</button>
    </section>
  </div>
</div>
