const { contextBridge, ipcRenderer } = require("electron");

function asArrayBuffer(bytes) {
  if (bytes instanceof ArrayBuffer) return bytes;
  const view = bytes.buffer ? bytes : new Uint8Array(bytes);
  return view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength);
}

contextBridge.exposeInMainWorld("shotli", {
  isDesktop: true,
  platform: process.platform,
  savePng: (bytes, filename) => ipcRenderer.invoke("save-png", bytes, filename),
  onOpenFiles: (callback) => {
    const listener = (_event, files) => {
      callback(
        files.map((file) => ({
          name: file.name,
          type: file.type,
          bytes: asArrayBuffer(file.bytes),
        })),
      );
    };
    ipcRenderer.on("open-files", listener);
    ipcRenderer.send("renderer-ready");
    return () => ipcRenderer.removeListener("open-files", listener);
  },
  onExport: (callback) => {
    const listener = () => callback();
    ipcRenderer.on("export-png", listener);
    return () => ipcRenderer.removeListener("export-png", listener);
  },
});
