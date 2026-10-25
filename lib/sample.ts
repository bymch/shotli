import type { LoadedImage } from "./types";

export async function createSampleImage(): Promise<LoadedImage> {
  const canvas = document.createElement("canvas");
  canvas.width = 1440;
  canvas.height = 900;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Couldn't create a sample screenshot.");

  ctx.fillStyle = "#FFFFFF";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.fillStyle = "#FAFAFB";
  ctx.fillRect(0, 0, 250, canvas.height);
  ctx.strokeStyle = "#EBEBEE";
  ctx.beginPath();
  ctx.moveTo(250.5, 0);
  ctx.lineTo(250.5, canvas.height);
  ctx.stroke();

  const nav = ["Overview", "Invoices", "Customers", "Payouts", "Settings"];
  ctx.textAlign = "left";
  ctx.textBaseline = "middle";
  ctx.font = "14px Geist, ui-sans-serif, sans-serif";
  nav.forEach((item, index) => {
    const y = 72 + index * 44;
    if (item === "Customers") {
      round(ctx, 16, y - 16, 218, 32, 8);
      ctx.fillStyle = "#EEF4FF";
      ctx.fill();
      ctx.fillStyle = "#3478F6";
    } else {
      ctx.fillStyle = "#3F3F46";
    }
    ctx.fillText(item, 32, y);
  });

  ctx.textBaseline = "alphabetic";
  ctx.fillStyle = "#18181B";
  ctx.font = "600 28px Geist, ui-sans-serif, sans-serif";
  ctx.fillText("Customers", 290, 80);
  ctx.font = "15px Geist, ui-sans-serif, sans-serif";
  ctx.fillStyle = "#71717A";
  ctx.fillText("Workspace members who can receive invoices.", 290, 112);

  const rows = [
    ["Ada Lovelace", "ada@example.com", "Owner", "Active"],
    ["Grace Hopper", "grace@example.com", "Admin", "Active"],
    ["Alan Turing", "alan@example.com", "Billing", "Invited"],
  ];
  rows.forEach((row, index) => {
    const y = 160 + index * 88;
    round(ctx, 290, y, 1100, 72, 12);
    ctx.fillStyle = "#FFFFFF";
    ctx.fill();
    ctx.strokeStyle = "#E7E7EA";
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(326, y + 36, 18, 0, Math.PI * 2);
    ctx.fillStyle = index === 2 ? "#FEF3C7" : "#E8EEF7";
    ctx.fill();
    ctx.fillStyle = "#18181B";
    ctx.font = "600 16px Geist, ui-sans-serif, sans-serif";
    ctx.fillText(row[0], 360, y + 28);
    ctx.font = "14px Geist, ui-sans-serif, sans-serif";
    ctx.fillStyle = "#71717A";
    ctx.fillText(row[1], 360, y + 50);
    ctx.fillStyle = "#3F3F46";
    ctx.fillText(row[2], 1040, y + 40);
    ctx.fillStyle = row[3] === "Active" ? "#157F3D" : "#92400E";
    ctx.fillText(row[3], 1240, y + 40);
  });

  round(ctx, 290, 450, 1100, 140, 12);
  ctx.fillStyle = "#F8FAFC";
  ctx.fill();
  ctx.strokeStyle = "#E7E7EA";
  ctx.stroke();
  ctx.fillStyle = "#18181B";
  ctx.font = "600 15px Geist, ui-sans-serif, sans-serif";
  ctx.fillText("API token", 314, 492);
  ctx.font = "14px ui-monospace, monospace";
  ctx.fillStyle = "#3F3F46";
  ctx.fillText("sk_live_example_51SHOTLI0000DEMO", 314, 528);
  ctx.font = "13px Geist, ui-sans-serif, sans-serif";
  ctx.fillStyle = "#71717A";
  ctx.fillText("Dummy value for trying redaction. It is not a real secret.", 314, 560);

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
