<script lang="ts">
  import { onMount } from "svelte";
  import { ipcInvoke, isTauri } from "../../utils/ipc.js";

  type Agent = { name: string; path: string };
  type OllamaModel = { name: string; size: number };
  type TagHit = { tag: string; chinese: string; category: number; match: string; score: number };
  type PromptRow = { en: string; zh: string };
  type PromptResult = { prompt: string; rows: PromptRow[]; tags: TagHit[]; warnings?: string; model: string };
  type Card = "generator" | "notes" | "translator";
  const KEY = "mooshieui.plus.promptGenerator.v1";
  const modes = [
    { value: "anima", label: "Anima Turbo｜TAG + 自然英文" },
    { value: "wai", label: "WAI Illustrious｜TAG" },
    { value: "noob", label: "NoobAI XL｜TAG" },
    { value: "qwen", label: "Qwen-Image｜自然英文" },
  ];
  const categories = [
    {value:"all",label:"全部"}, {value:"0",label:"一般"}, {value:"1",label:"繪師"},
    {value:"3",label:"作品"}, {value:"4",label:"角色"}, {value:"5",label:"其他"},
  ];

  let agents = $state<Agent[]>([]);
  let models = $state<OllamaModel[]>([]);
  let agentPath = $state("");
  let model = $state("");
  let probeBusy = $state(false);
  let probeStatus = $state("");
  let ollamaNotice = $state("");
  let mode = $state("anima");
  let request = $state("");
  let result = $state<PromptResult | null>(null);
  let generating = $state(false);
  let loading = $state(false);
  let status = $state("");
  let error = $state("");
  let sidebarOpen = $state(true);
  let cardOrder = $state<Card[]>(["generator", "notes", "translator"]);
  let dragged = $state<Card | null>(null);
  let scratchpad = $state("");
  let sourceText = $state("");
  let translatedText = $state("");
  let direction = $state<"zh-en" | "en-zh">("zh-en");
  let translating = $state(false);
  let tagQuery = $state("");
  let tagCategory = $state("all");
  let tagResults = $state<TagHit[]>([]);
  let tagError = $state("");
  let tagBusy = $state(false);
  let manualTags = $state<string[]>([]);
  let tagDebounce: ReturnType<typeof setTimeout> | null = null;
  let lastSearch = 0;

  async function call<T>(action: string, payload: Record<string, unknown> = {}): Promise<T> {
    if (!isTauri) throw new Error("Prompt Generator 需使用 MooshieUI Windows 桌面版。");
    return ipcInvoke<T>("picture_generator_action", { action, payload });
  }
  onMount(() => {
    try {
      const x = JSON.parse(localStorage.getItem(KEY) ?? "{}");
      if (Array.isArray(x.order) && x.order.length === 3 && ["generator","notes","translator"].every(k => x.order.includes(k))) cardOrder = x.order;
      if (typeof x.note === "string") scratchpad = x.note;
      if (typeof x.sidebar === "boolean") sidebarOpen = x.sidebar;
      if (typeof x.mode === "string" && modes.some(m=>m.value===x.mode)) mode = x.mode;
      if (typeof x.request === "string") request = x.request;
      if (typeof x.agent === "string") agentPath = x.agent;
      if (typeof x.model === "string") model = x.model;
    } catch {}
    void refreshInputs();
    return () => { if (tagDebounce) clearTimeout(tagDebounce); };
  });
  $effect(() => {
    try {
      localStorage.setItem(KEY,JSON.stringify({order:cardOrder,note:scratchpad,sidebar:sidebarOpen,mode,request,agent:agentPath,model}));
    } catch {}
  });
  async function refreshInputs() {
    loading = true; error = ""; ollamaNotice = ""; probeStatus = "";
    try {
      const [a,m] = await Promise.allSettled([call<Agent[]>("agents"),call<OllamaModel[]>("models")]);
      if (a.status === "fulfilled") {
        agents = a.value;
        if (!agents.some(x=>x.path===agentPath)) agentPath=agents[0]?.path ?? "";
      } else error = "無法取得 AGENT："+String(a.reason);
      if (m.status === "fulfilled") {
        models = m.value;
        if (!model.trim()) model=models[0]?.name ?? "";
        ollamaNotice = `已從 Ollama 讀取 ${models.length} 個可選模型（尚未逐一測試生成）。`;
      } else {
        models = [];
        ollamaNotice = "無法讀取 Ollama："+String(m.reason)+"。可自行輸入模型名稱，啟動 Ollama 後再測試。";
      }
    } finally { loading=false; }
  }
  async function probeModel() {
    if (!model.trim() || probeBusy) return;
    probeBusy=true;probeStatus="";
    try {
      const selected=model.trim();
      await call<{model:string;callable:boolean}>("probe",{model:selected});
      probeStatus=`${selected} 已透過 Ollama /api/chat 成功回傳文字。`;
    } catch(e) {probeStatus="模型呼叫測試失敗："+String(e);}
    finally {probeBusy=false;}
  }
  async function generate() {
    if (!request.trim() || !model || !agentPath || generating) return;
    generating=true; error=""; status="正在透過現有 prompt_generator 執行 Ollama 與 TAG 查詢…";
    try {
      result = await call<PromptResult>("generate",{agentPath,model,mode,request,manualTags});
      if (!result?.prompt || !Array.isArray(result.rows)) throw new Error("沒有得到有效提示詞或中文對照");
      status="已生成第一版提示詞，可複製後繼續修改。";
    } catch(e) { error=String(e);status=""; }
    finally { generating=false; }
  }
  async function searchTags() {
    const q=tagQuery.trim(), seq=++lastSearch;
    if (!q) { tagResults=[]; tagError=""; tagBusy=false; return; }
    tagBusy=true;tagError="";
    try {
      const results=await call<TagHit[]>("search",{query:q,limit:30});
      if (seq === lastSearch) tagResults=results.filter(x=>tagCategory==="all" || x.category===Number(tagCategory));
    } catch(e) { if(seq===lastSearch){tagError=String(e);tagResults=[];} }
    finally { if(seq===lastSearch)tagBusy=false; }
  }
  function scheduleSearch() {
    if(tagDebounce)clearTimeout(tagDebounce);
    tagDebounce=setTimeout(()=>void searchTags(),320);
  }
  function changeCategory(value:string){tagCategory=value;void searchTags();}
  function addTag(tag:string) {
    if(!manualTags.includes(tag))manualTags=[...manualTags,tag];
  }
  function removeTag(tag:string){manualTags=manualTags.filter(x=>x!==tag);}
  function appendNote(tag:string) { scratchpad += (scratchpad.trim() ? "\n" : "") + tag; }
  function selectModel(value: string) {
    if (!value || value === model) return;
    model = value;
    probeStatus = "";
    translatedText = "";
  }
  async function copy(text:string) {
    try { await navigator.clipboard.writeText(text);status="已複製至剪貼簿。"; }
    catch(e){error="複製失敗："+String(e);}
  }
  async function translate() {
    if(!sourceText.trim() || !model || translating)return;
    translating=true; translatedText="";error="";
    try {
      const x=await call<{text:string;provider:string}>("translate",{text:sourceText,model,direction});
      translatedText=x.text;
    } catch(e) {error=String(e);}
    finally{translating=false;}
  }
  function googleUrl() {
    const source=direction==="zh-en"?"zh-TW":"en";
    const dest=direction==="zh-en"?"en":"zh-TW";
    return "https://translate.google.com/?sl="+source+"&tl="+dest+"&text="+encodeURIComponent(sourceText)+"&op=translate";
  }
  function moveCard(card:Card, delta:number){
    const pos=cardOrder.indexOf(card), next=pos+delta;
    if(next<0||next>=cardOrder.length)return;
    const copy=[...cardOrder];[copy[pos],copy[next]]=[copy[next],copy[pos]];cardOrder=copy;
  }
  function dropCard(target:Card) {
    if(!dragged || target===dragged) return;
    const list=[...cardOrder].filter(x=>x!==dragged);
    list.splice(list.indexOf(target),0,dragged);
    cardOrder=list;dragged=null;
  }
</script>

<div class="flex h-full min-h-0 w-full overflow-hidden bg-neutral-950 text-neutral-100">
  <main class="min-w-0 flex-1 overflow-y-auto p-2.5">
    {#if !isTauri}
      <p class="mb-2 rounded border border-amber-600/40 bg-amber-900/20 p-2 text-xs text-amber-200">本頁只支援 Windows 桌面版，未啟動本地生成服務。</p>
    {/if}
    <div class="grid grid-cols-1 items-start gap-2 md:grid-cols-2">
    {#each cardOrder as card (card)}
      <section class="rounded-lg border border-neutral-700/70 bg-neutral-900 p-3 {card === 'generator' ? 'md:col-span-2' : ''}"
        ondragover={(e)=>e.preventDefault()} ondrop={(e)=>{e.preventDefault();dropCard(card);}}>
        <div class="mb-2 flex items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <span draggable="true" role="button" tabindex="0" aria-label={"拖曳"+card+"調整順序"}
              ondragstart={()=>dragged=card} ondragend={()=>dragged=null}
              class="cursor-grab select-none text-neutral-500 hover:text-neutral-300" title="拖曳調整順序">⠿</span>
            <h3 class="text-xs font-semibold tracking-wide">{card==="generator"?"PROMPT GENERATOR":card==="notes"?"筆記區":"翻譯（Ollama）"}</h3>
          </div>
          <div class="flex gap-1">
            <button type="button" aria-label="上移卡片" onclick={()=>moveCard(card,-1)} class="rounded border border-neutral-700 px-2 text-xs text-neutral-400 hover:text-white">↑</button>
            <button type="button" aria-label="下移卡片" onclick={()=>moveCard(card,1)} class="rounded border border-neutral-700 px-2 text-xs text-neutral-400 hover:text-white">↓</button>
          </div>
        </div>
        {#if card==="generator"}
          <div class="grid grid-cols-1 gap-2 md:grid-cols-2">
            <label class="text-[11px] text-neutral-400">AGENT
              <select bind:value={agentPath} class="mt-1 w-full min-w-0 rounded border border-neutral-700 bg-neutral-800 p-1.5 text-xs text-neutral-200">
                {#each agents as agent (agent.path)}<option value={agent.path}>{agent.name}</option>{/each}
              </select>
            </label>
            <div class="min-w-0">
              <label class="block text-[11px] text-neutral-400">Ollama 已安裝模型（尚未驗證可生成）
                <select value={models.some(m=>m.name===model)?model:""} onchange={(e)=>selectModel(e.currentTarget.value)}
                  class="mt-1 w-full rounded border border-neutral-700 bg-neutral-800 p-1.5 text-xs text-neutral-200">
                  <option value="">請選擇模型／使用下方自訂名稱</option>
                  {#each models as m (m.name)}<option value={m.name}>{m.name}</option>{/each}
                </select>
              </label>
              <div class="mt-1 flex flex-wrap gap-1">
                <input aria-label="手動輸入 Ollama 模型名稱" bind:value={model} oninput={()=>{probeStatus="";translatedText="";}} maxlength="180"
                  placeholder="自訂 Ollama 模型名稱，例如 qwen3:8b" class="min-w-0 flex-1 rounded border border-neutral-700 bg-neutral-950 p-1.5 text-xs text-neutral-100" />
                <button type="button" disabled={loading} onclick={()=>void refreshInputs()} class="rounded border border-neutral-700 px-2 text-xs disabled:opacity-40">刷新清單</button>
                <button type="button" disabled={probeBusy || !model.trim()} onclick={()=>void probeModel()} class="rounded border border-indigo-500 px-2 text-xs disabled:opacity-40">{probeBusy?"測試中…":"測試呼叫"}</button>
              </div>
            </div>
          </div>
          <p class="mt-2 text-[11px] text-neutral-400">使用本功能前須另行 <a href="https://ollama.com/download" target="_blank" rel="noopener noreferrer" class="text-indigo-300 underline">安裝 Ollama</a> 並啟動服務。B 版已內附所需的執行元件，不需安裝 Node.js 或編譯工具。</p>
          {#if ollamaNotice}<p class="mt-1 text-[11px] text-amber-300">{ollamaNotice}</p>{/if}
          {#if probeStatus}<p role="status" class="mt-1 text-[11px] text-indigo-300">{probeStatus}</p>{/if}
          <label class="mt-2 block text-[11px] text-neutral-400">繪圖模型／提示詞格式
            <select bind:value={mode} class="mt-1 w-full rounded border border-neutral-700 bg-neutral-800 p-1.5 text-xs text-neutral-200">
              {#each modes as m}<option value={m.value}>{m.label}</option>{/each}
            </select>
          </label>
          <label class="mt-2 block text-[11px] text-neutral-400">中文繪圖需求
            <textarea bind:value={request} rows="4" maxlength="3000" placeholder="輸入人物、服裝、動作、互動、場景與構圖…" class="mt-1 w-full resize-y rounded border border-neutral-700 bg-neutral-950 p-2 text-xs text-neutral-100"></textarea>
          </label>
          <div class="flex justify-end">
            <button type="button" disabled={generating || !model || !agentPath || !request.trim()} onclick={()=>void generate()}
              class="rounded bg-emerald-700 px-4 py-1.5 text-xs font-medium text-white hover:bg-emerald-600 disabled:opacity-40">
              {generating?"正在生成…":"生成第一版提示詞 →"}
            </button>
          </div>
          {#if result}
            <div class="mt-3 space-y-2">
              <div class="flex items-center justify-between text-xs"><strong>Positive Prompt</strong><button type="button" class="text-indigo-300 hover:underline" onclick={()=>void copy(result!.prompt)}>複製英文</button></div>
              <pre class="max-h-48 overflow-auto whitespace-pre-wrap break-words rounded border border-neutral-800 bg-neutral-950 p-2 text-xs text-neutral-200">{result.prompt}</pre>
              <strong class="block text-xs">中文對照</strong>
              <div class="max-h-56 overflow-auto rounded border border-neutral-800 text-[11px]">
                <table class="w-full table-fixed border-collapse"><thead class="bg-neutral-800 text-neutral-300"><tr><th class="w-1/2 p-1 text-left">英文原文</th><th class="p-1 text-left">繁體中文</th></tr></thead>
                  <tbody>{#each result.rows as row,i (i)}<tr class="border-t border-neutral-800"><td class="break-words p-1.5">{row.en}</td><td class="break-words p-1.5">{row.zh}</td></tr>{/each}</tbody>
                </table>
              </div>
              {#if result.warnings}<p class="text-[11px] text-amber-300">{result.warnings}</p>{/if}
            </div>
          {/if}
        {:else if card==="notes"}
          <textarea bind:value={scratchpad} rows="5" spellcheck="false" placeholder="筆記、TAG 暫存及提示詞草稿…（自動儲存，與原本筆記獨立）" class="w-full resize-y rounded border border-neutral-700 bg-neutral-950 p-2 text-xs text-neutral-100"></textarea>
          <div class="text-right"><button type="button" class="text-[11px] text-indigo-300" onclick={()=>void copy(scratchpad)}>複製筆記</button></div>
        {:else if card==="translator"}
          <p class="mb-2 text-[11px] text-amber-300">即時翻譯使用下方所選 Ollama 模型；Google 翻譯會另外開啟官方網站，不使用付費 API。</p>
          <label class="mb-2 block text-[11px] text-neutral-400">Ollama 翻譯模型（與上方雙向同步）
            <select aria-label="Ollama 翻譯模型" value={models.some(m=>m.name===model)?model:model?"__custom__":""}
              onchange={(e)=>selectModel(e.currentTarget.value)}
              class="mt-1 w-full min-w-0 rounded border border-neutral-700 bg-neutral-800 px-2 py-1.5 text-xs text-neutral-200">
              <option value="" disabled>尚未選擇 Ollama 模型</option>
              {#if model && !models.some(m=>m.name===model)}
                <option value="__custom__" disabled>目前自訂：{model}</option>
              {/if}
              {#each models as m (m.name)}<option value={m.name}>{m.name}</option>{/each}
            </select>
          </label>
          <div class="mb-2 flex items-center gap-2">
            <select bind:value={direction} class="rounded border border-neutral-700 bg-neutral-800 px-2 py-1 text-xs">
              <option value="zh-en">繁中 → 英文</option><option value="en-zh">英文 → 繁中</option>
            </select>
            <button type="button" onclick={()=>{direction=direction==="zh-en"?"en-zh":"zh-en";sourceText=translatedText;translatedText="";}} class="rounded border border-neutral-700 px-2 py-1 text-xs">⇄</button>
          </div>
          <div class="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <textarea rows="5" bind:value={sourceText} placeholder="輸入要翻譯的文字" class="min-w-0 w-full resize-y rounded border border-neutral-700 bg-neutral-950 p-2 text-xs"></textarea>
            <textarea rows="5" readonly value={translatedText} placeholder="真實翻譯結果將顯示於此" class="min-w-0 w-full resize-y rounded border border-neutral-700 bg-neutral-800 p-2 text-xs"></textarea>
          </div>
          <div class="mt-2 flex flex-wrap gap-2">
            <button type="button" disabled={translating || !sourceText.trim() || !model.trim()} onclick={()=>void translate()} class="rounded border border-indigo-500 px-2 py-1 text-xs disabled:opacity-40">{translating?"翻譯中…":"使用 Ollama 翻譯"}</button>
            <a href={googleUrl()} target="_blank" rel="noopener noreferrer" class="rounded border border-neutral-700 px-2 py-1 text-xs text-indigo-300 hover:border-indigo-500">開啟 Google 翻譯 ↗</a>
            <button type="button" onclick={()=>void copy(translatedText)} disabled={!translatedText} class="rounded border border-neutral-700 px-2 py-1 text-xs disabled:opacity-40">複製翻譯</button>
          </div>
        {/if}
      </section>
    {/each}
    </div>
    {#if status}<p role="status" class="rounded bg-emerald-900/20 px-2 py-1 text-[11px] text-emerald-300">{status}</p>{/if}
    {#if error}<p role="alert" class="rounded bg-red-900/30 px-2 py-1 text-[11px] text-red-300">{error}</p>{/if}
  </main>

  {#if sidebarOpen}
    <aside class="flex w-[30%] min-w-[235px] max-w-[420px] shrink-0 flex-col border-l border-neutral-700 bg-[#10222d] p-3 text-neutral-100">
      <div class="mb-3 flex items-center justify-between gap-1">
        <div><p class="text-[10px] font-bold tracking-[0.14em] text-amber-200">TAG LIBRARY</p><h3 class="mt-1 text-sm font-semibold">標籤探索</h3></div>
        <button type="button" class="rounded border border-neutral-600 px-2 py-1 text-xs" title="收合 TAG Library" onclick={()=>sidebarOpen=false}>×</button>
      </div>
      <input type="search" bind:value={tagQuery} oninput={scheduleSearch} class="w-full rounded border border-slate-600 bg-[#0e1923] p-2 text-xs" placeholder="搜尋中文、英文、角色 TAG…" />
      <select value={tagCategory} onchange={(e)=>changeCategory(e.currentTarget.value)} class="mt-2 w-full rounded border border-slate-600 bg-[#0e1923] p-1.5 text-xs">
        {#each categories as category}<option value={category.value}>{category.label}</option>{/each}
      </select>
      <p class="mt-2 text-[10px] text-neutral-400">{tagBusy?"正在查詢真實詞庫…":tagQuery?"查詢結果："+tagResults.length+" 筆":"輸入關鍵詞開始搜尋"}</p>
      {#if tagError}<p class="mt-1 text-xs text-amber-300">{tagError}</p>{/if}
      <div class="mt-2 min-h-0 flex-1 space-y-1.5 overflow-y-auto">
        {#each tagResults as hit (hit.tag)}
          <div class="rounded border border-slate-700/80 bg-[#142b38] p-2 text-[11px]">
            <div class="break-all font-medium text-neutral-100">{hit.tag}</div>
            <div class="mt-0.5 break-words text-emerald-200">{hit.chinese||"尚無中文對照"}</div>
            <div class="mt-1 text-[10px] text-neutral-400">{hit.match}</div>
            <div class="mt-1 flex gap-2 text-indigo-300">
              <button type="button" onclick={()=>addTag(hit.tag)} class="hover:underline">加入選取</button>
              <button type="button" onclick={()=>appendNote(hit.tag)} class="hover:underline">加入筆記</button>
              <button type="button" onclick={()=>void copy(hit.tag)} class="hover:underline">複製</button>
            </div>
          </div>
        {/each}
      </div>
      {#if manualTags.length}
        <div class="mt-2 max-h-32 overflow-y-auto border-t border-slate-600 pt-2">
          <p class="mb-1 text-[10px] text-neutral-400">已選 TAG（下次生成時加入）</p>
          <div class="flex flex-wrap gap-1">{#each manualTags as tag}<button type="button" onclick={()=>removeTag(tag)} title="移除" class="rounded bg-slate-700 px-1.5 py-1 text-[10px]">{tag} ×</button>{/each}</div>
        </div>
      {/if}
    </aside>
  {:else}
    <button type="button" onclick={()=>sidebarOpen=true} class="shrink-0 self-start rounded-l border border-r-0 border-neutral-600 bg-[#10222d] px-1.5 py-3 text-[11px] text-neutral-200" title="展開 TAG Library">TAG ▸</button>
  {/if}
</div>
