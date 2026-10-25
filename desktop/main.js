const { app, BrowserWindow, dialog, ipcMain, Menu, protocol, net, shell } = require("electron");
const fs = require("fs/promises");
const path = require("path");
const { pathToFileURL } = require("url");

const IMAGE_EXT = /\.(png|jpe?g|webp)$/i;

app.setName("Shotli");

protocol.registerSchemesAsPrivileged([
  {
    scheme: "shotli",
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      corsEnabled: true,
      stream: true,
    },
  },
]);

const outDir = path.resolve(__dirname, "../out");
let mainWindow = null;
const pendingFiles = [];
let rendererReady = false;

function mimeFor(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  if (extension === ".png") return "image/png";
  if (extension === ".jpg" || extension === ".jpeg") return "image/jpeg";
  if (extension === ".webp") return "image/webp";
  return "";
}

function filesFromArgv(argv) {
  return argv.filter((arg) => IMAGE_EXT.test(arg) && !arg.startsWith("-"));
}

async function deliver(filePaths) {
  if (!mainWindow) return;
  const files = [];
  for (const filePath of filePaths) {
    const type = mimeFor(filePath);
    if (!type) continue;
    try {
      const bytes = await fs.readFile(filePath);
      files.push({ name: path.basename(filePath), type, bytes });
    } catch {
      // Skip files that disappeared between the drop and the read.
    }
  }
  if (files.length > 0) mainWindow.webContents.send("open-files", files);
}

function queueFiles(filePaths) {
  if (rendererReady) {
    void deliver(filePaths);
    return;
  }
  pendingFiles.push(...filePaths);
}

function createWindow() {
  const mac = process.platform === "darwin";
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 900,
    minHeight: 640,
    title: "Shotli",
    backgroundColor: "#f1f1f1",
    titleBarStyle: mac ? "hiddenInset" : "default",
    trafficLightPosition: { x: 16, y: 16 },
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.once("ready-to-show", () => {
    if (process.env.SHOTLI_SMOKE === "1") return;
    mainWindow.show();
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("https://") || url.startsWith("http://")) void shell.openExternal(url);
    return { action: "deny" };
  });

  mainWindow.webContents.on("will-navigate", (event, url) => {
    if (!url.startsWith("shotli://")) event.preventDefault();
  });

  if (process.env.SHOTLI_SMOKE === "1") {
    mainWindow.webContents.on("did-finish-load", () => {
      mainWindow.webContents
        .executeJavaScript("document.body.innerText.includes('Shotli')")
        .then((ok) => {
          console.log(ok ? "SMOKE_OK" : "SMOKE_FAIL");
          app.exit(ok ? 0 : 1);
        })
        .catch((error) => {
          console.error("SMOKE_FAIL", error);
          app.exit(1);
        });
    });
  }

  void mainWindow.loadURL("shotli://app/");
}

function buildMenu() {
  const mac = process.platform === "darwin";
  const fileMenu = {
    label: "File",
    submenu: [
      {
        label: "Open…",
        accelerator: "CmdOrCtrl+O",
        click: async () => {
          const result = await dialog.showOpenDialog(mainWindow, {
            title: "Open a screenshot",
            properties: ["openFile"],
            filters: [{ name: "Images", extensions: ["png", "jpg", "jpeg", "webp"] }],
          });
          if (!result.canceled) queueFiles(result.filePaths);
        },
      },
      {
        label: "Export PNG…",
        accelerator: "CmdOrCtrl+S",
        click: () => mainWindow?.webContents.send("export-png"),
      },
      {
        label: "Export PNG",
        accelerator: "CmdOrCtrl+E",
        visible: false,
        click: () => mainWindow?.webContents.send("export-png"),
      },
      { type: "separator" },
      mac ? { role: "close" } : { role: "quit" },
    ],
  };

  const editMenu = {
    label: "Edit",
    submenu: [
      { role: "cut" },
      { role: "copy" },
      { role: "paste" },
      { role: "selectAll" },
    ],
  };

  const template = [];
  if (mac) {
    template.push({
      label: "Shotli",
      submenu: [
        { role: "about" },
        { type: "separator" },
        { role: "hide" },
        { role: "hideOthers" },
        { role: "unhide" },
        { type: "separator" },
        { role: "quit" },
      ],
    });
  }
  template.push(fileMenu, editMenu, { role: "windowMenu" });
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on("second-instance", (_event, argv) => {
    queueFiles(filesFromArgv(argv));
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });
}

app.on("open-file", (event, filePath) => {
  event.preventDefault();
  queueFiles([filePath]);
});

ipcMain.handle("save-png", async (event, bytes, filename) => {
  const windowForDialog = BrowserWindow.fromWebContents(event.sender);
  const safeName = String(filename || "shotli.png").replace(/[\\/]/g, "-");
  const result = await dialog.showSaveDialog(windowForDialog, {
    title: "Export PNG",
    defaultPath: path.join(app.getPath("pictures"), safeName),
    filters: [{ name: "PNG image", extensions: ["png"] }],
  });
  if (result.canceled || !result.filePath) return { saved: false };
  const filePath = result.filePath.toLowerCase().endsWith(".png") ? result.filePath : `${result.filePath}.png`;
  await fs.writeFile(filePath, Buffer.from(bytes));
  return { saved: true };
});

ipcMain.on("renderer-ready", () => {
  rendererReady = true;
  if (pendingFiles.length > 0) void deliver(pendingFiles.splice(0));
});

if (gotLock) app.whenReady().then(() => {
  app.setAboutPanelOptions({
    applicationName: "Shotli",
    applicationVersion: app.getVersion(),
    copyright: "© 2026 Michael",
    credits: "Make every screenshot look better.",
  });

  protocol.handle("shotli", (request) => {
    const url = new URL(request.url);
    let pathname = decodeURIComponent(url.pathname);
    if (pathname === "/" || pathname.endsWith("/")) pathname += "index.html";
    const relative = pathname.replace(/^\/+/, "");
    const filePath = path.resolve(outDir, relative);
    const root = `${outDir}${path.sep}`;
    if (filePath !== outDir && !filePath.startsWith(root)) {
      return new Response("Not found", { status: 404 });
    }
    return net.fetch(pathToFileURL(filePath).toString());
  });

  buildMenu();
  pendingFiles.push(...filesFromArgv(process.argv));
  createWindow();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin" || process.env.SHOTLI_SMOKE === "1") app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
