//! Desktop-only bridge to the portable Prompt Generator service.
//! The B installer ships a portable Node runtime beside the application; the
//! service code is embedded in this EXE. No model, setting, or private TAG data is bundled.
use serde_json::{json, Value};
use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use std::process::Stdio;
use std::time::Duration;

fn service_path() -> Option<std::path::PathBuf> {
    if let Some(override_path) = std::env::var_os("MOOSHIEUI_PROMPT_SERVICE") {
        return Some(std::path::PathBuf::from(override_path));
    }
    // The bundled service is the default on every computer. Do not silently
    // prefer a legacy app-data service from another installation or drive.
    // An explicit MOOSHIEUI_PROMPT_SERVICE override remains supported.
    None
}

fn node_path() -> std::path::PathBuf {
    if let Some(node) = std::env::current_exe().ok().and_then(|exe| exe.parent().map(|dir|
        dir.join("MooshieUIplus").join("PromptGenerator").join("node.exe"))) {
        if node.is_file() { return node; }
    }
    std::path::PathBuf::from("node")
}
const EMBEDDED_SERVICE: &str = include_str!("service.cjs");
const NODE_BRIDGE: &str = r#"
"use strict";
// Capture module.exports synchronously: Node's -e module may be cleared before stdin ends.
const builtinService=process.argv[1]==="builtin"?module.exports:null;
let input="";
process.stdin.setEncoding("utf8");
process.stdin.on("data",s=>input+=s);
process.stdin.on("end",async()=>{
 try {
  const service=builtinService||require(process.argv[1]);
  const arg=JSON.parse(input),p=arg.payload||{};
  let data;
  switch(arg.action){
   case "agents": data=service.getAgents(); break;
   case "models": data=await service.ollamaModels(); break;
   case "probe": {
     if(typeof service.probe==="function") {data=await service.probe(p.model);break;}
     if(typeof p.model!=="string"||!p.model.trim())throw Error("請先選擇模型");
     const response=await fetch("http://127.0.0.1:11434/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:p.model,stream:false,think:false,messages:[{role:"user",content:"Reply with OK."}],options:{temperature:0,num_predict:16}}),signal:AbortSignal.timeout(45000)});
     if(!response.ok)throw Error("Ollama 無法呼叫模型："+response.status);
     const obj=await response.json();
     if(!obj.message?.content?.trim())throw Error("模型沒有回傳文字");
     data={model:p.model,callable:true};break;
   }
   case "search": data=service.searchTags(p.query,Math.max(1,Math.min(40,p.limit||22))); break;
   case "generate": data=await service.generate(p); break;
   case "translate": {
     if(typeof service.translate==="function") {data=await service.translate(p);break;}
     if(typeof p.text!=="string"||!p.text.trim()||p.text.length>3000||!p.model)throw Error("請先選擇 Ollama 模型並輸入翻譯文字（3000 字內）");
     const to=p.direction==="en-zh"?"繁體中文":"英文";
     const response=await fetch("http://127.0.0.1:11434/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:p.model,stream:false,think:false,messages:[{role:"system",content:"Translate the text to "+to+". Preserve names and TAG syntax. Return translation only."},{role:"user",content:p.text}],options:{temperature:0,num_predict:1800,num_ctx:8192}}),signal:AbortSignal.timeout(110000)});
     if(!response.ok)throw Error("Ollama 翻譯失敗："+response.status);
     const obj=await response.json();data={text:obj.message?.content?.trim()||"",provider:"Ollama"};
     if(!data.text)throw Error("翻譯沒有回傳文字");break;
   }
   default: throw Error("Unsupported Prompt Generator action");
  }
  process.stdout.write(JSON.stringify({ok:true,data})+"\n");
 }catch(e){
  process.stdout.write(JSON.stringify({ok:false,error:String(e.message||e)})+"\n");
  process.exitCode=1;
 }
});
"#;

/// The frontend has no generic shell execution ability and cannot choose the Node script path.
#[tauri::command]
pub async fn picture_generator_action(action: String, payload: Value) -> Result<Value, String> {
    if !["agents", "models", "probe", "search", "generate", "translate"].contains(&action.as_str()) {
        return Err("不支援的 Prompt Generator 操作".into());
    }
    let external_service = service_path();
    if let Some(ref service) = external_service {
        if !service.is_file() {
            return Err(format!("自訂 Prompt Generator 服務不存在：{}", service.display()));
        }
    }
    let mut cmd = Command::new(node_path());
    if let Some(service) = external_service {
        cmd.arg("-e").arg(NODE_BRIDGE).arg(service);
    } else {
        // The built-in service is compiled into the EXE. It never needs a D:/ or H:/ source path.
        cmd.arg("-e").arg(format!("{EMBEDDED_SERVICE}\n{NODE_BRIDGE}"))
            .arg("builtin");
    }
    cmd.stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped());
    cmd.kill_on_drop(true);
    #[cfg(windows)]
    {
        cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW
    }
    let mut child = cmd.spawn().map_err(|e| format!("Prompt Generator 執行元件無法啟動：{e}。請在模組管理器檢查 GitHub 更新以補齊可攜執行元件。"))?;
    let message = json!({"action":action,"payload":payload}).to_string();
    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(message.as_bytes()).await.map_err(|e| e.to_string())?;
    }
    let output = tokio::time::timeout(Duration::from_secs(180),child.wait_with_output())
        .await.map_err(|_| "Prompt Generator 執行逾時（180 秒）".to_string())?
        .map_err(|e| e.to_string())?;
    let raw = String::from_utf8(output.stdout).map_err(|_| "生成器回傳非 UTF-8 內容".to_string())?;
    let result: Value = serde_json::from_str(raw.trim())
        .map_err(|_| format!("生成器回傳格式錯誤：{}", String::from_utf8_lossy(&output.stderr).chars().take(180).collect::<String>()))?;
    if result.get("ok").and_then(Value::as_bool) != Some(true) {
        return Err(result.get("error").and_then(Value::as_str).unwrap_or("生成器執行失敗").to_owned());
    }
    Ok(result.get("data").cloned().unwrap_or(Value::Null))
}
