//! LoRA user annotations, separate from safetensors weights and application config.
use std::path::{Path, PathBuf};
use std::sync::Arc;
use serde_json::{json, Value};
use crate::commands::api::{resolve_model_path, save_model_sidecar_thumbnail_inner};
use crate::state::AppState;
#[cfg(feature = "desktop")]
use tauri::State;

const TYPES: &[&str] = &["style", "character", "effect", "other"];

fn read_json(path: &Path, fallback: Value) -> Result<Value, String> {
    if !path.exists() { return Ok(fallback); }
    let bytes = std::fs::read(path).map_err(|e| e.to_string())?;
    serde_json::from_slice(&bytes).map_err(|e| format!("無法解析 {}: {e}", path.display()))
}

fn write_json(path: &Path, value: &Value) -> Result<(), String> {
    let bytes = serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?;
    std::fs::create_dir_all(path.parent().ok_or("無法取得資料目錄")?)
        .map_err(|e| e.to_string())?;
    // Persist to the independent data directory, never inside the LoRA weights.
    std::fs::write(path, bytes).map_err(|e| e.to_string())
}

fn data_root() -> Result<PathBuf, String> {
    Ok(crate::config::app_data_dir()
        .ok_or("無法取得 MooshieUI 使用者資料目錄")?
        .join("addons").join("lora-manager"))
}
fn info_file() -> Result<PathBuf, String> { Ok(data_root()?.join("lora-info.json")) }
fn category_file() -> Result<PathBuf, String> { Ok(data_root()?.join("lora-categories.json")) }

fn model_entry(value: &Value) -> Result<Value, String> {
    let array = |key: &str| -> Result<Vec<String>, String> {
        let values = value.get(key).and_then(Value::as_array).ok_or(format!("缺少 {key} 陣列"))?;
        if values.len() > 60 { return Err(format!("{key} 超過上限")); }
        let mut result = Vec::new();
        for v in values {
            let tag = v.as_str().ok_or(format!("{key} 必須為文字"))?.trim();
            if tag.len() > 180 { return Err(format!("{key} 單項過長")); }
            if !tag.is_empty() && !result.iter().any(|old| old == tag) {
                result.push(tag.to_owned());
            }
        }
        Ok(result)
    };
    let types = array("types")?;
    if types.is_empty() || types.iter().any(|t| !TYPES.contains(&t.as_str())) {
        return Err("LoRA 類型只能是 style、character、effect、other，且不可為空".into());
    }
    let tags = array("tags")?;
    let trigger_words = array("triggerWords")?;
    let notes = value.get("notes").and_then(Value::as_str).ok_or("備註必須為文字")?.trim();
    let base_model = value.get("baseModel").and_then(Value::as_str).ok_or("底模必須為文字")?.trim();
    if notes.len() > 8000 || base_model.len() > 256 { return Err("備註或底模文字超過上限".into()); }
    Ok(json!({"types":types,"tags":tags,"triggerWords":trigger_words,"notes":notes,"baseModel":base_model}))
}

pub(crate) async fn lora_info_action_inner(
    state: &AppState,
    action: &str,
    filename: &str,
    entry: Option<Value>,
    image_bytes: Option<Vec<u8>>,
    gallery_filename: Option<&str>,
    gallery_dir: Option<&Path>,
) -> Result<Value, String> {
    if action == "list" {
        let data = read_json(&info_file()?, json!({"schemaVersion":1,"entries":{}}))?;
        let categories = read_json(&category_file()?, json!({"schemaVersion":1,"types":{}}))?;
        return Ok(json!({"entries":data.get("entries").cloned().unwrap_or(json!({})),
                         "types":categories.get("types").cloned().unwrap_or(json!({}))}));
    }
    if !["load", "save", "cover"].contains(&action) { return Err("不支援的 LoRA 資訊操作".into()); }
    let (comfy_path, extras) = {
        let config = state.config.read().await;
        (config.comfyui_path.clone(), config.extra_model_paths.clone())
    };
    let model_path = resolve_model_path(&comfy_path, extras.as_deref(), "loras", filename)
        .filter(|p| p.extension().and_then(|s| s.to_str())
            .is_some_and(|s| s.eq_ignore_ascii_case("safetensors")))
        .ok_or("找不到指定的 LoRA safetensors 檔案")?;
    if action == "cover" {
        if let Some(bytes) = image_bytes {
            if bytes.is_empty() || bytes.len() > 15 * 1024 * 1024 {
                return Err("預覽圖片必須小於 15 MB".into());
            }
            let img = image::load_from_memory(&bytes).map_err(|e| format!("無法開啟圖片: {e}"))?;
            if u64::from(img.width()) * u64::from(img.height()) > 40_000_000 {
                return Err("圖片解析度過高".into());
            }
            let target = model_path.with_extension("png");
            img.save(&target).map_err(|e| format!("無法儲存封面: {e}"))?;
        } else if gallery_filename.is_some() {
            save_model_sidecar_thumbnail_inner(state, "loras", filename, None, gallery_filename, gallery_dir)
                .await.map_err(|e| e.to_string())?;
        } else { return Err("尚未選擇封面圖片".into()); }
        return Ok(json!({"saved":true}));
    }
    let mut data = read_json(&info_file()?, json!({"schemaVersion":1,"entries":{}}))?;
    let mut cats = read_json(&category_file()?, json!({"schemaVersion":1,"types":{}}))?;
    if action == "load" {
        return Ok(json!({
            "entry":data.get("entries").and_then(|v| v.get(filename)).cloned(),
            "types":cats.get("types").and_then(|v| v.get(filename.replace('\\', "/")))
                .or_else(|| cats.get("types").and_then(|v| v.get(filename)))
                .or_else(|| cats.get("types").and_then(|v| v.get(Path::new(filename).file_name()?.to_str()?))).cloned()
        }));
    }
    let record = model_entry(&entry.ok_or("缺少模型資訊")?)?;
    let type_values = record["types"].clone();
    let entries = data.as_object_mut().ok_or("資訊資料格式錯誤")?
        .entry("entries").or_insert_with(|| json!({}));
    entries.as_object_mut().ok_or("entries 格式錯誤")?.insert(filename.into(), record);
    let types = cats.as_object_mut().ok_or("分類資料格式錯誤")?
        .entry("types").or_insert_with(|| json!({}));
    types.as_object_mut().ok_or("types 格式錯誤")?.insert(filename.replace('\\', "/"), type_values);
    // Category file is existing user data: retain all other keys and entries.
    write_json(&info_file()?, &data)?;
    write_json(&category_file()?, &cats)?;
    Ok(json!({"saved":true}))
}

#[cfg(feature = "desktop")]
#[tauri::command]
pub async fn lora_info_action(
    state: State<'_, Arc<AppState>>,
    action: String,
    filename: String,
    entry: Option<Value>,
    image_bytes: Option<Vec<u8>>,
    gallery_filename: Option<String>,
) -> Result<Value, String> {
    lora_info_action_inner(state.inner(), &action, &filename, entry, image_bytes,
                           gallery_filename.as_deref(), None).await
}
