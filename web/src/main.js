import { startGame } from "./game.js";

const app = document.querySelector("#app");
async function boot() {
  try {
    await startGame(app);
  } catch (error) {
    const ui = document.querySelector("#ui");
    ui.innerHTML = `<section class="card error"><h1>Dino Kazı</h1><p>${error.message}</p><button onclick="location.reload()">Retry</button></section>`;
    console.error(error);
  }
}
boot();
