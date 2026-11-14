import { writeFile, mkdir } from "node:fs/promises";

if (typeof globalThis.FileReader === "undefined") {
  globalThis.FileReader = class FileReader {
    readAsArrayBuffer(blob) {
      blob.arrayBuffer().then((buffer) => {
        this.result = buffer;
        this.onloadend?.();
      });
    }
  };
}
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { GLTFExporter } from "three/addons/exporters/GLTFExporter.js";
import { buildFossil, buildLiving } from "../src/dino_rig.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const outDir = path.join(root, "godot/assets/models");

const catalog = JSON.parse(readFileSync(path.join(root, "shared/data/dinosaurs.json"), "utf8"));

function parse(scene, animations) {
  const exporter = new GLTFExporter();
  return new Promise((resolve, reject) => {
    exporter.parse(scene, resolve, reject, { binary: true, animations });
  });
}

await mkdir(outDir, { recursive: true });

for (const dino of catalog) {
  const living = buildLiving(dino, "high");
  const clips = living.userData.clips;
  living.traverse((child) => {
    if (child.isMesh) child.visible = true;
    child.userData = {};
  });
  living.userData = {};
  let tris = 0;
  living.traverse((child) => {
    if (child.isMesh && child.geometry?.index) tris += child.geometry.index.count / 3;
  });
  const livingBin = await parse(living, clips);
  const livingPath = path.join(outDir, `${dino.id}.glb`);
  await writeFile(livingPath, Buffer.from(livingBin));
  const fossil = buildFossil(dino);
  fossil.userData = {};
  let fossilTris = 0;
  fossil.traverse((child) => {
    if (child.isMesh && child.geometry?.index) fossilTris += child.geometry.index.count / 3;
  });
  const fossilBin = await parse(fossil, []);
  const fossilPath = path.join(outDir, `${dino.id}_skeleton.glb`);
  await writeFile(fossilPath, Buffer.from(fossilBin));
  console.log(`${dino.id} living ${tris.toFixed(0)} tris ${livingBin.byteLength} bytes, skeleton ${fossilTris.toFixed(0)} tris`);
}
