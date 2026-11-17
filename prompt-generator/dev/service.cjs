"use strict";
// Portable Prompt Generator for MooshieUIplus. No private rules or TAG corpus are bundled.
const fs = require("node:fs");
const path = require("node:path");
const DEFAULT_AGENT = "builtin:default";
const BASIC_RULES = [
  "Convert Traditional Chinese image requests to concise English prompts.",
  "Preserve characters, clothing, poses, relations, camera, style and any literal LoRA triggers.",
  "Never add attributes that the user did not request.",
  "For Anima Turbo use verified canonical tags followed by natural English when available.",
  "For WAI Illustrious and NoobAI XL prefer verified tags; otherwise use plain English.",
  "For Qwen-Image use clear English sentences.",
  "Always return Traditional Chinese translations aligned to the English phrases."
].join("\n");
const MODES = {anima:"Anima Turbo",wai:"WAI Illustrious",noob:"NoobAI XL",qwen:"Qwen-Image"};
const root = process.env.PICTURE_PROJECT_ROOT || "";
const tagFile = process.env.MOOSHIEUI_PROMPT_TAGS || "";
const ollamaHost = (process.env.OLLAMA_HOST || "http://127.0.0.1:11434").replace(/\/$/,"");
const ollamaUrl = ollamaHost.startsWith("http") ? ollamaHost : "http://" + ollamaHost;
let tagsCache;
function sourcePath(){
  // Private TAG data is never bundled; users may point to their own local dictionary.
  return tagFile&&fs.existsSync(tagFile)?tagFile:"";
}
function loadTags(){
  if(tagsCache!==undefined)return tagsCache;
  const file=sourcePath();
  if(!file)return (tagsCache=[]);
  let obj;try{obj=JSON.parse(fs.readFileSync(file,"utf8"));}
  catch(e){throw Error("無法解析 TAG 詞庫："+e.message);}
  if(!Array.isArray(obj))throw Error("TAG 詞庫不是陣列："+file);
  return (tagsCache=obj.filter(x=>x&&typeof x.n==="string").map(x=>({
    tag:x.n,category:Number(x.c)||0,count:Number(x.p)||0,
    aliases:Array.isArray(x.a)?x.a.filter(a=>typeof a==="string"):[]
  })));
}
function norm(x){return String(x||"").trim().toLowerCase().replace(/\s+/g,"_").replace(/\\/g,"");}
function chineseLabel(t){return t.aliases.find(x=>/[\u3400-\u9fff]/u.test(x))||"中文未收錄";}
function searchTags(query,limit=22){
  const q=norm(query);if(!q)return [];
  return loadTags().map(x=>{
    const name=norm(x.tag),alias=x.aliases.map(norm);let score=100;
    if(name===q)score=0;
    else if(alias.includes(q))score=1;
    else if(name.startsWith(q))score=2;
    else if(alias.some(a=>a.startsWith(q)))score=3;
    else if(q.length>=2&&alias.some(a=>a.includes(q)))score=4;
    else if(q.length>=3&&name.includes(q))score=5;
    return {x,score};
  }).filter(x=>x.score<100).sort((a,b)=>a.score-b.score||b.x.count-a.x.count)
    .slice(0,Math.max(1,Math.min(40,Number(limit)||22)))
    .map(({x,score})=>({tag:x.tag,chinese:chineseLabel(x),category:x.category,score,
      match:score<=1?"精確":score<=3?"前綴":"包含"}));
}
function getAgents(){
  const out=[{name:"內建基本規則（可攜版）",path:DEFAULT_AGENT}];
  if(root && fs.existsSync(path.join(root,"PROMPT_RULES.md"))){
    for(const file of fs.readdirSync(root).filter(n=>n.endsWith(".md")&&n.toUpperCase().includes("AGENT"))){
      out.push({name:file,path:path.join(root,file)});
    }
  }
  return out;
}
function readAgent(id){
  if(id===DEFAULT_AGENT)return BASIC_RULES;
  if(!root||!id||typeof id!=="string")throw Error("找不到 AGENT：請選擇內建規則。");
  const resolved=path.resolve(id),r=path.resolve(root)+path.sep;
  if(!resolved.startsWith(r)||!resolved.toLowerCase().endsWith(".md")||!fs.existsSync(resolved))
    throw Error("AGENT 檔案不在設定的規則目錄。");
  const stat=fs.statSync(resolved);
  if(!stat.isFile()||stat.size>180000)throw Error("AGENT 檔案不支援或過大。");
  return fs.readFileSync(resolved,"utf8");
}
async function api(endpoint,body,timeout=120000){
  let res;try{
    res=await fetch(ollamaUrl+endpoint,{
      method:body===undefined?"GET":"POST",
      headers:body===undefined?undefined:{"Content-Type":"application/json"},
      body:body===undefined?undefined:JSON.stringify(body),
      signal:AbortSignal.timeout(timeout)
    });
  }catch(e){throw Error("無法連線 Ollama（"+ollamaUrl+"），請確認已啟動："+e.message);}
  if(!res.ok)throw Error("Ollama "+endpoint+" 回傳 "+res.status+"："+(await res.text()).slice(0,220));
  return res.json();
}
async function ollamaModels(){
  const result=await api("/api/tags",undefined,7000);
  if(!Array.isArray(result.models))throw Error("Ollama 模型清單格式無效。");
  return result.models.filter(x=>typeof x.name==="string"&&x.name&&!/embedding/i.test(x.name))
    .map(x=>({name:x.name,size:x.size||0}));
}
async function probe(model){
  if(typeof model!=="string"||!model.trim()||model.length>180)throw Error("請先選擇有效模型。");
  const result=await api("/api/chat",{
    model:model.trim(),stream:false,think:false,
    messages:[{role:"user",content:"Reply with the word OK."}],
    options:{temperature:0,num_predict:16}
  },45000);
  if(typeof result.message?.content!=="string"||!result.message.content.trim())
    throw Error("模型已回應 API，但沒有產生文字，無法確認可用於提示詞生成。");
  return {model:model.trim(),callable:true};
}
async function translate({model,text,direction}){
  if(typeof text!=="string"||!text.trim()||text.length>3000)throw Error("翻譯文字需為 1–3000 字。");
  if(typeof model!=="string"||!model.trim())throw Error("請先選擇 Ollama 模型。");
  const language=direction==="en-zh"?"Traditional Chinese":"English";
  const result=await api("/api/chat",{
    model:model.trim(),stream:false,think:false,
    messages:[{role:"system",content:"Translate precisely into "+language+
      ". Preserve original names, TAG syntax, line breaks and punctuation. Output only translation."},
      {role:"user",content:text}],options:{temperature:0,num_predict:1800,num_ctx:8192}
  });
  const output=result.message?.content?.trim()||"";
  if(!output)throw Error("翻譯沒有回傳文字。");
  return {text:output,provider:"Ollama"};
}
function parseJson(text){
  const s=String(text||"").trim().replace(/^\`\`\`(?:json)?/i,"").replace(/\`\`\`$/,"").trim();
  try{return JSON.parse(s);}catch{
    const a=s.indexOf("{"),b=s.lastIndexOf("}");
    if(a<0||b<=a)throw Error("模型未回傳有效 JSON");
    return JSON.parse(s.slice(a,b+1));
  }
}
async function generate({model,agentPath,mode,request,manualTags=[]}){
  if(!MODES[mode])throw Error("不支援的繪圖模型格式。");
  if(typeof model!=="string"||!model.trim())throw Error("請先選擇 Ollama 模型。");
  if(typeof request!=="string"||!request.trim()||request.length>3000)
    throw Error("請輸入 1–3000 字的繁體中文繪圖需求。");
  const agent=readAgent(agentPath);
  const userRules=(root&&fs.existsSync(path.join(root,"PROMPT_RULES.md")))
    ?fs.readFileSync(path.join(root,"PROMPT_RULES.md"),"utf8").slice(0,2200):BASIC_RULES;
  const system="You prepare image-generation prompts for "+MODES[mode]+". "+
    "Output ONLY a JSON object: {\"terms\":[\"search term\"],\"sentences\":[{\"en\":\"English sentence.\",\"zh\":\"繁體中文。\"}]}. "+
    "Provide 1–8 short terms for TAG searching and 1–4 aligned English/Traditional Chinese sentences. "+
    "Do not invent characters, styles, outfits, backgrounds, camera angles or details. "+
    "Keep character names and user-specified special syntax exactly. "+
    "Only the application may select canonical TAGs; do not claim any TAG was verified. "+
    "Keep English free of Chinese; produce no markdown or explanations.\n"+userRules+"\n"+agent.slice(0,2200);
  const body={
    model:model.trim(),stream:false,think:false,format:"json",
    messages:[{role:"system",content:system},{role:"user",content:"繪圖需求："+request}],
    options:{temperature:0.1,num_ctx:8192,num_predict:900}
  };
  let data,lastError;
  for(let attempt=0;attempt<2;attempt++){
    const response=await api("/api/chat",body,120000);
    try{
      const obj=parseJson(response.message?.content);
      const sentences=Array.isArray(obj.sentences)?obj.sentences
        .filter(x=>x&&typeof x.en==="string"&&typeof x.zh==="string"&&
            /[A-Za-z]/.test(x.en)&&/[\u3400-\u9fff]/u.test(x.zh)&&!/[\u3400-\u9fff]/u.test(x.en))
        .slice(0,4).map(x=>({en:x.en.trim(),zh:x.zh.trim()})):[];
      if(!sentences.length)throw Error("模型沒有提供有效英文與繁體中文對照。");
      data={terms:Array.isArray(obj.terms)?obj.terms.filter(x=>typeof x==="string").slice(0,8):[],sentences};
      break;
    }catch(e){lastError=e;body.messages[0].content+="\nPrevious response invalid. Return strictly valid JSON with both languages.";}
  }
  if(!data)throw Error("兩次呼叫後仍無法解析回覆："+lastError.message);
  const available=loadTags(),tags=[],seen=new Set();
  if(mode!=="qwen"&&available.length){
    const manual=Array.isArray(manualTags)?manualTags.slice(0,30):[];
    for(const t of manual){
      const matched=available.find(x=>x.tag===t);
      if(matched&&!seen.has(t)){seen.add(t);tags.push({tag:t,chinese:chineseLabel(matched)});}
    }
    for(const term of data.terms){
      const best=searchTags(term,4).find(x=>x.score<=2);
      if(best&&!seen.has(best.tag)&&best.category!==3&&best.category!==4){
        seen.add(best.tag);tags.push({tag:best.tag,chinese:best.chinese});
      }
    }
  }
  const tagText=tags.map(x=>x.tag).join(", ");
  const sentences=data.sentences;
  const natural=sentences.map(x=>x.en).join(" ");
  const prompt=mode==="qwen"?natural:(tagText?(tagText+(mode==="anima"?"\n\n":"\n")+natural):natural);
  const rows=[...tags.map(t=>({en:t.tag,zh:t.chinese})),...sentences];
  return {prompt,rows,tags,mode,model:model.trim(),
    warnings:available.length?"":"未載入 TAG 原始詞庫，本次只產生自然英文提示詞；沒有宣稱任何 TAG 已核實。"};
}
module.exports={MODES,getAgents,readAgent,loadTags,searchTags,ollamaModels,probe,translate,generate};
