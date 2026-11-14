import puppeteer from "puppeteer-core";
import { mkdir } from "node:fs/promises";
import path from "node:path";

const outDir = path.resolve("../docs/concept");
await mkdir(outDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: "/usr/bin/google-chrome",
  headless: true,
  args: [
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--use-angle=swiftshader",
    "--enable-webgl",
    "--ignore-gpu-blocklist",
    "--window-size=1440,900",
  ],
});

const shots = [
  ["menu", "menu.png", 1440, 900],
  ["dig", "dig.png", 1440, 900],
  ["museum", "museum.png", 1440, 900],
  ["reveal", "reveal.png", 1440, 900],
  ["passport", "passport.png", 1440, 900],
  ["dig", "dig-mobile.png", 390, 844],
];

const page = await browser.newPage();
page.on("pageerror", (error) => console.log("PAGEERROR", error.message));
page.on("console", (msg) => {
  if (msg.type() === "error") console.log("CONSOLE", msg.text());
});

for (const [shot, file, width, height] of shots) {
  await page.setViewport({ width, height, deviceScaleFactor: 1 });
  await page.goto(`http://127.0.0.1:47321/?shot=${shot}&lang=tr`, { waitUntil: "networkidle0", timeout: 30000 });
  await page.waitForFunction(() => document.documentElement.dataset.ready === "1", { timeout: 15000 });
  await new Promise((resolve) => setTimeout(resolve, 700));
  const target = path.join(outDir, file);
  await page.screenshot({ path: target });
  console.log("saved", target);
}

await browser.close();
