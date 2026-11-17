/** Lightweight editable COCO-18 OpenPose geometry for creative-tools 22. */
export type PosePoint = { x: number; y: number; visible: boolean };
export type PosePerson = {
  id: number;
  name: string;
  joints: PosePoint[];
  visible: boolean;
  locked: boolean;
};
export type PosePreset = "standing" | "arms_up";

export const POSE_JOINT_LABELS = [
  "鼻", "頸", "右肩", "右肘", "右腕", "左肩", "左肘", "左腕",
  "右髖", "右膝", "右踝", "左髖", "左膝", "左踝",
  "右眼", "左眼", "右耳", "左耳",
] as const;

export const POSE_LIMBS: ReadonlyArray<readonly [number, number, string]> = [
  [1, 2, "#ff5500"], [2, 3, "#ffaa00"], [3, 4, "#ffff00"],
  [1, 5, "#aaff00"], [5, 6, "#55ff00"], [6, 7, "#00ff00"],
  [1, 8, "#00ff55"], [8, 9, "#00ffaa"], [9, 10, "#00ffff"],
  [1, 11, "#00aaff"], [11, 12, "#0055ff"], [12, 13, "#0000ff"],
  [1, 0, "#ff0000"], [0, 14, "#ff00aa"], [14, 16, "#ff0055"],
  [0, 15, "#aa00ff"], [15, 17, "#5500ff"],
];

export function createPosePerson(id: number, cx = 0.5, cy = 0.53, preset: PosePreset = "standing"): PosePerson {
  // All positions are normalized to the full composition, not a particular image size.
  const points: Array<[number, number]> = [
    [0, -.33], [0, -.23], [-.10, -.23], [-.15, -.05], [-.18, .10],
    [.10, -.23], [.15, -.05], [.18, .10],
    [-.075, .04], [-.09, .22], [-.10, .42],
    [.075, .04], [.09, .22], [.10, .42],
    [-.025, -.35], [.025, -.35], [-.06, -.34], [.06, -.34],
  ];
  if (preset === "arms_up") {
    points[3] = [-.16, -.40]; points[4] = [-.18, -.59];
    points[6] = [.16, -.40]; points[7] = [.18, -.59];
  }
  return {
    id, name: `Person ${id}`, visible: true, locked: false,
    joints: points.map(([x, y]) => ({
      x: Math.max(0, Math.min(1, cx + x)),
      y: Math.max(0, Math.min(1, cy + y)),
      visible: true,
    })),
  };
}

export function parseOpenPoseJson(text: string): PosePerson[] {
  const value: unknown = JSON.parse(text);
  // ComfyUI POSE_KEYPOINT may wrap a single still-image result in a list.
  const frame = Array.isArray(value) && value.length === 1 ? value[0] : value;
  if (!frame || typeof frame !== "object" || Array.isArray(frame)) {
    throw new Error("姿勢 JSON 必須是物件或單張圖片的關節陣列");
  }
  const obj = frame as Record<string, unknown>;
  if (!Array.isArray(obj.people) || obj.people.length === 0) {
    throw new Error("姿勢 JSON 缺少 people 陣列或人物資料");
  }
  if (obj.people.length > 20) throw new Error("最多匯入 20 個人物");
  const width = Number(obj.canvas_width);
  const height = Number(obj.canvas_height);
  return obj.people.map((raw, i) => {
    const person = raw as { pose_keypoints_2d?: unknown };
    const data = person?.pose_keypoints_2d;
    if (!Array.isArray(data) || data.length !== 54 && data.length !== 75 ||
        !data.every(v => typeof v === "number" && Number.isFinite(v))) {
      throw new Error(`Person ${i + 1} 的 pose_keypoints_2d 必須是 COCO-18 或 BODY-25 數值陣列`);
    }
    const body25 = data.length === 75;
    const indices = body25
      ? [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
      : Array.from({ length: 18 }, (_, n) => n);
    const normalized = indices.every(n => data[n * 3] <= 1 && data[n * 3 + 1] <= 1);
    if (!normalized && (!(width > 0) || !(height > 0))) {
      throw new Error("絕對座標姿勢 JSON 須提供 canvas_width 與 canvas_height，避免座標失真");
    }
    const joints = indices.map(n => {
      const x = data[n * 3] / (normalized ? 1 : width);
      const y = data[n * 3 + 1] / (normalized ? 1 : height);
      return {
        x: Math.max(0, Math.min(1, x)),
        y: Math.max(0, Math.min(1, y)),
        visible: data[n * 3 + 2] > 0,
      };
    });
    return { id: i + 1, name: `Person ${i + 1}`, joints, visible: true, locked: false };
  });
}

export async function renderPosePng(people: PosePerson[], width: number, height: number): Promise<number[]> {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 64 || height < 64 ||
      width * height > 4096 * 4096) throw new Error("姿勢畫布尺寸不合法");
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("無法建立姿勢畫布");
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, width, height);
  ctx.lineCap = "round";
  const size = Math.max(3, Math.min(width, height) / 140);
  for (const person of people) {
    if (!person.visible) continue;
    ctx.lineWidth = size * 2.5;
    for (const [from, to, color] of POSE_LIMBS) {
      const a = person.joints[from], b = person.joints[to];
      if (!a.visible || !b.visible) continue;
      ctx.strokeStyle = color;
      ctx.beginPath();
      ctx.moveTo(a.x * width, a.y * height);
      ctx.lineTo(b.x * width, b.y * height);
      ctx.stroke();
    }
    ctx.fillStyle = "#ffffff";
    for (const joint of person.joints) {
      if (!joint.visible) continue;
      ctx.beginPath();
      ctx.arc(joint.x * width, joint.y * height, size, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  const blob = await new Promise<Blob>((resolve, reject) =>
    canvas.toBlob(b => b ? resolve(b) : reject(new Error("無法輸出骨架 PNG")), "image/png"));
  return Array.from(new Uint8Array(await blob.arrayBuffer()));
}
