import type { LoadedImage } from "./types";

export async function createSampleImage(): Promise<LoadedImage> {
  const canvas = document.createElement("canvas");
  canvas.width = 1440;
  canvas.height = 900;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Couldn't create a sample screenshot.");

  ctx.fillStyle = "#F5F5F7";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  round(ctx, 48, 36, 1344, 828, 18);
  ctx.fillStyle = "#FFFFFF";
  ctx.fill();
  ctx.strokeStyle = "#E4E4E7";
  ctx.stroke();

  ctx.fillStyle = "#FAFAFA";
  ctx.fillRect(48, 36, 1344, 56);
  ctx.strokeStyle = "#EBEBEE";
  ctx.beginPath();
  ctx.moveTo(48, 92);
  ctx.lineTo(1392, 92);
  ctx.stroke();

  for (const [index, color] of ["#FF5F57", "#FEBC2E", "#28C840"].entries()) {
    ctx.beginPath();
    ctx.arc(78 + index * 22, 64, 6, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
  }
  ctx.fillStyle = "#71717A";
  ctx.font = "600 15px Geist, ui-sans-serif, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("Northwind — Billing", 720, 64);

  ctx.fillStyle = "#FAFAFB";
  ctx.fillRect(48, 92, 250, 772);
  ctx.strokeStyle = "#EBEBEE";
  ctx.beginPath();
  ctx.moveTo(298, 92);
  ctx.lineTo(298, 864);
  ctx.stroke();

  const nav = ["Overview", "Invoices", "Customers", "Payouts", "Settings"];
  ctx.textAlign = "left";
  ctx.font = "14px Geist, ui-sans-serif, sans-serif";
  nav.forEach((item, index) => {
    const y = 140 + index * 40;
    if (item === "Customers") {
      round(ctx, 64, y - 16, 210, 32, 8);
      ctx.fillStyle = "#EEF4FF";
      ctx.fill();
      ctx.fillStyle = "#3478F6";
    } else {
      ctx.fillStyle = "#3F3F46";
    }
    ctx.fillText(item, 80, y);
  });

  ctx.fillStyle = "#18181B";
  ctx.font = "600 28px Geist, ui-sans-serif, sans-serif";
  ctx.fillText("Customers", 340, 150);
  ctx.font = "15px Geist, ui-sans-serif, sans-serif";
  ctx.fillStyle = "#71717A";
  ctx.fillText("Workspace members who can receive invoices.", 340, 184);

  const rows = [
    ["Ada Lovelace", "ada@example.com", "Owner", "Active"],
    ["Grace Hopper", "grace@example.com", "Admin", "Active"],
    ["Alan Turing", "alan@example.com", "Billing", "Invited"],
  ];
  rows.forEach((row, index) => {
    const y = 250 + index * 88;
    round(ctx, 340, y, 1000, 72, 12);
    ctx.fillStyle = "#FFFFFF";
    ctx.fill();
    ctx.strokeStyle = "#E7E7EA";
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(384, y + 36, 18, 0, Math.PI * 2);
    ctx.fillStyle = index === 2 ? "#FEF3C7" : "#E8EEF7";
    ctx.fill();
    ctx.fillStyle = "#18181B";
    ctx.font = "600 16px Geist, ui-sans-serif, sans-serif";
    ctx.fillText(row[0], 418, y + 28);
    ctx.font = "14px Geist, ui-sans-serif, sans-serif";
    ctx.fillStyle = "#71717A";
    ctx.fillText(row[1], 418, y + 50);
    ctx.fillStyle = "#3F3F46";
    ctx.fillText(row[2], 980, y + 40);
    ctx.fillStyle = row[3] === "Active" ? "#157F3D" : "#92400E";
    ctx.fillText(row[3], 1160, y + 40);
  });

  round(ctx, 340, 540, 1000, 150, 12);
  ctx.fillStyle = "#F8FAFC";
  ctx.fill();
  ctx.strokeStyle = "#E7E7EA";
  ctx.stroke();
  ctx.fillStyle = "#18181B";
  ctx.font = "600 15px Geist, ui-sans-serif, sans-serif";
  ctx.fillText("API token", 364, 578);
  ctx.font = "14px ui-monospace, monospace";
  ctx.fillStyle = "#3F3F46";
  ctx.fillText("sk_live_example_51SHOTLI0000DEMO", 364, 614);
  ctx.font = "13px Geist, ui-sans-serif, sans-serif";
  ctx.fillStyle = "#71717A";
  ctx.fillText("Dummy value for trying redaction. It is not a real secret.", 364, 648);

  const bitmap = await createImageBitmap(canvas);
  return {
    bitmap,
    width: bitmap.width,
    height: bitmap.height,
    name: "sample-screenshot.png",
    scaled: false,
  };
}

function round(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
