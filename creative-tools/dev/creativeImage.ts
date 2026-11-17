/** Raster preparation for creative-tools. The input remains untouched. */
export interface ImageRaster {
  bytes: number[];
  width: number;
  height: number;
}

async function canvasPng(canvas: HTMLCanvasElement): Promise<number[]> {
  const blob = await new Promise<Blob>((resolve, reject) =>
    canvas.toBlob((item) => item ? resolve(item) : reject(new Error("PNG encoding failed")), "image/png"),
  );
  return Array.from(new Uint8Array(await blob.arrayBuffer()));
}

export async function imageRaster(bytes: number[]): Promise<ImageRaster> {
  const blob = new Blob([new Uint8Array(bytes)], { type: "image/png" });
  const bitmap = await createImageBitmap(blob);
  try {
    const canvas = document.createElement("canvas");
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("2D canvas unavailable");
    ctx.drawImage(bitmap, 0, 0);
    return { bytes: await canvasPng(canvas), width: bitmap.width, height: bitmap.height };
  } finally {
    bitmap.close();
  }
}

export type ExtendSide = "up" | "down" | "left" | "right" | "all";

export function outpaintSize(width: number, height: number, side: ExtendSide, pixels: number) {
  const top = side === "up" || side === "all" ? pixels : 0;
  const bottom = side === "down" || side === "all" ? pixels : 0;
  const left = side === "left" || side === "all" ? pixels : 0;
  const right = side === "right" || side === "all" ? pixels : 0;
  return { width: width + left + right, height: height + top + bottom, top, left };
}

/**
 * Prepares two PNGs for the existing inpainting graph:
 * - padded original image
 * - red-channel mask: 255 = regenerate, 0 = keep original
 * An 8px overlap blends the seam instead of exposing a hard edge.
 */
export async function prepareOutpaint(
  inputBytes: number[],
  side: ExtendSide,
  pixels: number,
): Promise<{ image: number[]; mask: number[]; width: number; height: number }> {
  const bitmap = await createImageBitmap(new Blob([new Uint8Array(inputBytes)]));
  try {
    const layout = outpaintSize(bitmap.width, bitmap.height, side, pixels);
    if (layout.width > 2048 || layout.height > 2048) {
      throw new Error("Output exceeds 2048px. Reduce extension for 8GB VRAM.");
    }
    const image = document.createElement("canvas");
    image.width = layout.width;
    image.height = layout.height;
    const ctx = image.getContext("2d");
    if (!ctx) throw new Error("Canvas unavailable");
    // Edge color extension reduces harsh black seams before denoising.
    ctx.drawImage(bitmap, layout.left, layout.top);
    if (layout.left > 0) ctx.drawImage(bitmap, 0, 0, 1, bitmap.height, 0, layout.top, layout.left, bitmap.height);
    if (layout.top > 0) ctx.drawImage(bitmap, 0, 0, bitmap.width, 1, layout.left, 0, bitmap.width, layout.top);
    if (layout.width > layout.left + bitmap.width)
      ctx.drawImage(bitmap, bitmap.width - 1, 0, 1, bitmap.height, layout.left + bitmap.width, layout.top, layout.width - layout.left - bitmap.width, bitmap.height);
    if (layout.height > layout.top + bitmap.height)
      ctx.drawImage(bitmap, 0, bitmap.height - 1, bitmap.width, 1, layout.left, layout.top + bitmap.height, bitmap.width, layout.height - layout.top - bitmap.height);
    // Mask white exterior, and a small feathering strip just inside the original.
    const mask = document.createElement("canvas");
    mask.width = layout.width;
    mask.height = layout.height;
    const mc = mask.getContext("2d");
    if (!mc) throw new Error("Mask canvas unavailable");
    mc.fillStyle = "#fff";
    mc.fillRect(0, 0, layout.width, layout.height);
    mc.fillStyle = "#000";
    mc.fillRect(layout.left, layout.top, bitmap.width, bitmap.height);
    const feather = Math.min(12, pixels);
    const grad = (x0: number, y0: number, x1: number, y1: number, x: number, y: number, w: number, h: number) => {
      const g = mc.createLinearGradient(x0, y0, x1, y1);
      g.addColorStop(0, "#fff");
      g.addColorStop(1, "#000");
      mc.fillStyle = g;
      mc.fillRect(x, y, w, h);
    };
    if (layout.left > 0) grad(layout.left, 0, layout.left + feather, 0, layout.left, layout.top, feather, bitmap.height);
    if (layout.top > 0) grad(0, layout.top, 0, layout.top + feather, layout.left, layout.top, bitmap.width, feather);
    if (layout.width > layout.left + bitmap.width)
      grad(layout.left + bitmap.width, 0, layout.left + bitmap.width - feather, 0, layout.left + bitmap.width - feather, layout.top, feather, bitmap.height);
    if (layout.height > layout.top + bitmap.height)
      grad(0, layout.top + bitmap.height, 0, layout.top + bitmap.height - feather, layout.left, layout.top + bitmap.height - feather, bitmap.width, feather);
    return { image: await canvasPng(image), mask: await canvasPng(mask), width: layout.width, height: layout.height };
  } finally {
    bitmap.close();
  }
}
