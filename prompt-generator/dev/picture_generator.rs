//! Desktop-only bridge to the user's existing prompt_generator/desktop/service.cjs.
//! This does not copy the TAG dictionary or run arbitrary scripts from UI input.
use serde_json::{json, Value};
use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use std::process::Stdio;
use std::time::Duration;

fn service_path() -> Option<std::path::PathBuf> {
    std::env::var_os("MOOSHIEUI_PROMPT_SERVICE")
        .map(std::path::PathBuf::from)
        .or_else(|| crate::config::app_data_dir()
            .map(|dir| dir.join("addons").join("prompt-generator").join("desktop").join("service.cjs")))
}
const NODE_BRIDGE: &str = r#"
"use strict";
const fs=require("node:fs");
let input="";
process.stdin.setEncoding("utf8");
process.stdin.on("data",s=>input+=s);
process.stdin.on("end",async()=>{
 try {
  const service=require(process.argv[1]);
  const arg=JSON.parse(input),p=arg.payload||{};
  let data;
  switch(arg.action){
   case "agents": data=service.getAgents(); break;
   case "models": data=await service.ollamaModels(); break;
   case "search": data=service.searchTags(p.query,Math.max(1,Math.min(40,p.limit||22))); break;
   case "generate": data=await service.generate(p); break;
   case "translate": {
     if(typeof p.text!=="string"||p.text.length>3000||!p.text.trim()||!p.model)throw Error("請先選擇 Ollama 模型並輸入翻譯文字（3000 字內）");
     const to=p.direction==="en-zh"?"繁體中文":"英文";
     const response=await fetch("http://127.0.0.1:11434/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:p.model,stream:false,think:false,messages:[{role:"system",content:"You are a careful translation engine. Translate the user text to "+to+". Preserve names, TAG syntax, punctuation and line breaks. Return translation ONLY, no explanations."},{role:"user",content:p.text}],options:{temperature:0,num_predict:1800,num_ctx:8192}}),signal:AbortSignal.timeout(110000)});
     if(!response.ok)throw Error("Ollama 翻譯失敗："+response.status);
     const body=await response.json(); data={text:body.message?.content?.trim()||"",provider:"Ollama（非 Google 翻譯）"};
     if(!data.text)throw Error("翻譯沒有回傳文字");
     break;
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
    if !["agents", "models", "search", "generate", "translate"].contains(&action.as_str()) {
        return Err("不支援的 Prompt Generator 操作".into());
    }
    let service = service_path().ok_or("無法取得 Prompt Generator 服務路徑")?;
    if !service.is_file() {
        return Err(format!("尚未設定 Prompt Generator 服務：{}", service.display()));
    }
    let mut cmd = Command::new("node");
    cmd.arg("-e").arg(NODE_BRIDGE).arg(&service);
    cmd.stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped());
    cmd.kill_on_drop(true);
    #[cfg(windows)]
    {
        cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW
    }
    let mut child = cmd.spawn().map_err(|e| format!("Node.js 無法執行：{e}"))?;
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
