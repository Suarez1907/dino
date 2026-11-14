import * as THREE from "three";
import { catalog, dinosaurs, sites, dinoById, siteById, pick, t } from "./content.js";
import { allPlaced, holdDig, siteUnlocked, starsFor, tapTool } from "./rules.js";
import { createAudio } from "./audio.js";
import { animateDino, buildDino, buildExplorer, buildPati, setBoneState, setRigQuality } from "./dino.js";
import {
  addProps,
  addSpot,
  applyGrade,
  burstDust,
  carveTerrain,
  clearScene,
  createView,
  dressRoom,
  dressWorld,
  loadLook,
  makeDust,
  resizeView,
  updateAtmosphere,
  updateDust,
} from "./world.js";

const SAVE_KEY = "dino-kazi-save-v1";

const defaultSave = () => ({
  lang: "tr",
  tutorialDone: false,
  sessionElapsed: 0,
  stickers: [],
  settings: {
    music: 0.55,
    sfx: 0.85,
    voice: 1,
    haptics: true,
    largeText: false,
    colorblind: false,
    guideArrow: false,
    effects: true,
    quality: "medium",
    sessionMinutes: 0,
    pin: "",
  },
  sites: {},
});

export async function startGame(app) {
  const canvas = app.querySelector("#view");
  const ui = app.querySelector("#ui");
  let view;
  try {
    view = createView(canvas);
  } catch (error) {
    ui.innerHTML = `<div class="card error"><h1>Dino Kazı</h1><p>${error.message}</p></div>`;
    return;
  }
  const audio = createAudio();
  const save = loadSave();
  const params = new URLSearchParams(location.search);
  const shot = params.get("shot");
  const siteParam = params.get("site");
  const shotSite = sites.some((item) => item.id === siteParam) ? siteParam : sites[0].id;
  if (params.get("lang")) save.lang = params.get("lang") === "en" ? "en" : "tr";
  const state = {
    save,
    screen: "menu",
    siteId: sites[0].id,
    tool: "shovel",
    spots: [],
    groups: new Map(),
    player: null,
    pati: null,
    dino: null,
    dust: null,
    sun: null,
    joy: new THREE.Vector2(),
    keys: new Set(),
    holding: false,
    holdLocked: false,
    near: null,
    detector: 0,
    toast: "",
    toastTime: 0,
    tutorial: 0,
    moved: 0,
    camYaw: 0.2,
    time: 0,
    revealAge: 0,
    spoke: false,
    drag: null,
    breakOn: false,
    gate: null,
  };
  applyA11y();
  audio.apply(save.settings);
  window.addEventListener("resize", () => resizeView(view));
  resizeView(view);
  window.addEventListener("pointerdown", () => audio.unlock(), { once: true });
  window.addEventListener("keydown", (event) => {
    state.keys.add(event.key.toLowerCase());
    const index = "123456".indexOf(event.key);
    if (index >= 0 && state.screen === "dig") selectTool(catalog.tools[index].id);
    if (event.key === "r" && state.screen === "dig") detect();
  });
  window.addEventListener("keyup", (event) => state.keys.delete(event.key.toLowerCase()));
  ui.addEventListener("pointerdown", onPointerDown);
  ui.addEventListener("input", (event) => {
    const slider = event.target.closest?.("input[data-slider]");
    if (!slider) return;
    state.save.settings[slider.dataset.slider] = Number(slider.value) / 100;
    audio.apply(state.save.settings);
    writeSave();
  });
  ui.addEventListener("pointermove", onPointerMove);
  window.addEventListener("pointerup", onPointerUp);

  await loadLook(view.renderer);

  if (shot === "dig") {
    state.siteId = shotSite;
    enterDig(true);
  } else if (shot === "museum") {
    prepareShotBones(shotSite, true);
    enterMuseum(shotSite);
  } else if (shot === "reveal") {
    prepareShotBones(shotSite, true);
    sitesBones(shotSite).forEach((bone) => {
      bone.placed = true;
    });
    persistSite(shotSite);
    enterReveal(shotSite);
  } else if (shot === "passport") {
    save.sites[sites[0].id] = { ...(save.sites[sites[0].id] || {}), revealed: true };
    if (!save.stickers.includes("first_bone")) save.stickers.push("first_bone", "gentle");
    showPassport();
    buildVista(sites[0].id);
  } else {
    showMenu();
  }

  let last = performance.now();
  function frame(now) {
    const dt = Math.min(0.033, (now - last) / 1000);
    last = now;
    state.time += dt;
    tick(dt);
    applyGrade(view, save.settings);
    if (save.settings.effects && save.settings.quality !== "low") view.composer.render();
    else view.renderer.render(view.scene, view.camera);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  setTimeout(() => {
    document.documentElement.dataset.ready = "1";
  }, 700);

  function lang() {
    return save.lang === "en" ? "en" : "tr";
  }
  function text(key, extra) {
    return t(lang(), key, extra);
  }

  function tick(dt) {
    if (!state.breakOn && state.screen !== "menu" && state.screen !== "passport" && state.screen !== "settings") {
      if (save.settings.sessionMinutes > 0) {
        save.sessionElapsed += dt;
        if (save.sessionElapsed >= save.settings.sessionMinutes * 60) {
          state.breakOn = true;
          showBreak();
          writeSave();
        }
      }
    }
    if (state.toastTime > 0) {
      state.toastTime -= dt;
      if (state.toastTime <= 0) setText("[data-toast]", "");
    }
    if (state.screen === "menu" || state.screen === "sites" || state.screen === "passport" || state.screen === "settings") {
      state.camYaw += dt * 0.18;
      view.camera.position.set(Math.sin(state.camYaw) * 9, 4.1, Math.cos(state.camYaw) * 9);
      view.camera.lookAt(0, 1.2, 2);
      if (state.dino) animateDino(state.dino, state.time);
    } else if (state.screen === "dig") tickDig(dt);
    else if (state.screen === "museum") {
      if (state.dino) animateDino(state.dino, state.time);
      if (state.drag) moveProxy(state.drag.x, state.drag.y);
    } else if (state.screen === "reveal") tickReveal(dt);
    if (state.dust) updateDust(state.dust, dt);
    updateAtmosphere(view.scene, dt);
    if (state.dino) setRigQuality(state.dino, save.settings.quality || "medium");
  }

  function tickDig(dt) {
    state.detector = Math.max(0, state.detector - dt);
    const wish = state.joy.clone();
    if (state.keys.has("a") || state.keys.has("arrowleft")) wish.x -= 1;
    if (state.keys.has("d") || state.keys.has("arrowright")) wish.x += 1;
    if (state.keys.has("w") || state.keys.has("arrowup")) wish.y -= 1;
    if (state.keys.has("s") || state.keys.has("arrowdown")) wish.y += 1;
    const forward = new THREE.Vector3();
    view.camera.getWorldDirection(forward);
    forward.y = 0;
    forward.normalize();
    const right = new THREE.Vector3().crossVectors(forward, new THREE.Vector3(0, 1, 0)).normalize();
    const move = right.multiplyScalar(wish.x).add(forward.multiplyScalar(-wish.y));
    if (move.length() > 1) move.normalize();
    if (state.player && move.length() > 0.05) {
      state.player.position.addScaledVector(move, 4.6 * dt);
      state.player.rotation.y = Math.atan2(move.x, move.z);
      state.moved += move.length() * dt;
    }
    const sample = view.scene.userData.sample;
    if (sample && state.player) state.player.position.y = sample(state.player.position.x, state.player.position.z);
    if (state.pati && state.player) {
      const dest = state.player.position.clone().add(new THREE.Vector3(-1.15, 0, 0.8));
      if (sample) dest.y = sample(dest.x, dest.z);
      state.pati.position.lerp(dest, 1 - Math.exp(-2.4 * dt));
    }
    const focus = state.player ? state.player.position.clone().add(new THREE.Vector3(0, 1.1, 0)) : new THREE.Vector3();
    const desired = focus.clone().add(new THREE.Vector3(Math.sin(state.camYaw) * 6.4, 3.4, Math.cos(state.camYaw) * 6.4));
    view.camera.position.lerp(desired, 1 - Math.exp(-4 * dt));
    view.camera.lookAt(focus);
    if (state.sun) {
      state.sun.position.copy(focus).add(new THREE.Vector3(10, 16, 6));
      state.sun.target.position.copy(focus);
    }
    state.near = null;
    let best = 1.9;
    for (const spot of state.spots) {
      if (spot.collected) continue;
      const dist = Math.hypot(state.player.position.x - spot.pos[0], state.player.position.z - spot.pos[1]);
      if (dist < best) {
        best = dist;
        state.near = spot;
      }
    }
    const digging = (state.holding || state.keys.has(" ")) && state.near && !state.near.collected;
    if (digging) {
      if (!state.holdLocked) {
        const result = tapTool(state.near, state.tool, catalog);
        if (result.type === "fragile") {
          buzz(30);
          audio.play("crack");
          say(text("fragile_hit"));
          state.holdLocked = true;
          state.holding = false;
          persistSpot(state.near);
        } else if (result.type === "wrong") {
          buzz(12);
          audio.play("wrong");
          say(text("wrong_tool"));
          state.holdLocked = true;
          state.holding = false;
        }
      }
      if (!state.holdLocked && state.near) {
        const step = holdDig(state.near, dt);
        if (state.time % 0.18 < dt) puff(state.near, state.tool);
        if (step.type === "next") {
          say(text("layer_done"));
          state.holdLocked = false;
          persistSpot(state.near);
          if (state.tutorial === 4) state.tutorial = 5;
        } else if (step.type === "collected") {
          audio.play("collect");
          buzz(20);
          say(step.damage > 0.01 ? text("bone_cracked") : text("bone_safe"));
          award("first_bone");
          if (starsFor(state.spots) === 3) award("gentle");
          persistSpot(state.near);
          refreshSpotVisual(state.near);
          if (state.tutorial <= 6) {
            state.tutorial = 99;
            save.tutorialDone = true;
            say(text("t6"));
            audio.speak(text("t6"), lang());
          }
          state.holdLocked = false;
        }
      }
    } else state.holdLocked = false;
    updateTutorial();
    patchDigHud();
    for (const group of state.groups.values()) {
      const birds = group.getObjectByName("birds");
      if (birds) birds.rotation.x = Math.sin(state.time * 6) * 0.35;
      const marker = group.getObjectByName("marker");
      if (marker) marker.visible = Boolean(save.settings.colorblind);
    }
  }

  function tickReveal(dt) {
    const framed = new URLSearchParams(location.search).get("shot") === "reveal";
    if (framed) {
      state.revealAge = 0.4;
      state.dino.userData.anim = "idle";
    } else state.revealAge += dt;
    const info = dinoById(siteById(state.siteId).dino);
    if (!state.dino) return;
    if (state.revealAge < 1.3) state.dino.userData.anim = "idle";
    else if (state.revealAge < 5.2) {
      state.dino.userData.anim = "walk";
      const w = state.revealAge;
      state.dino.position.x = Math.sin(w * 0.55) * 2.4;
      state.dino.position.z = -1.2 + Math.cos(w * 0.55) * 1.4;
      state.dino.rotation.y = Math.atan2(Math.cos(w * 0.55), -Math.sin(w * 0.55));
      state.dino.userData.baseY = 0;
    } else if (state.revealAge < 8) {
      state.dino.userData.anim = "eat";
      setText("[data-sub]", text(info.diet === "herbivore" ? "eat_herb" : "eat_carn"));
    } else if (state.revealAge < 11.2) {
      state.dino.userData.anim = "roar";
      if (!state.spoke) {
        state.spoke = true;
        audio.play(`roar_${info.sounds.roar}`);
        const fact = pick(lang(), info.facts[0]);
        setText("[data-sub]", fact);
        audio.speak(`${text("hello_dino", { name: pick(lang(), info.name) })} ${fact}`, lang(), info.sounds.voice);
      }
    } else state.dino.userData.anim = "idle";
    animateDino(state.dino, state.time);
    const focus = state.dino.position.clone().add(new THREE.Vector3(0, 1.15, 0));
    if (!framed) {
      view.camera.position.lerp(focus.clone().add(new THREE.Vector3(3.4, 2.1, 5.2)), 1 - Math.exp(-2 * dt));
      view.camera.lookAt(focus);
    }
  }

  function showMenu() {
    state.screen = "menu";
    buildVista(sites[0].id);
    ui.innerHTML = `
      <div class="scrim"></div>
      <section class="card menu">
        <p class="kicker">${text("offline")}</p>
        <h1>${text("title")}</h1>
        <p>${text("tagline")}</p>
        <button class="primary" data-act="sites">${text("play")}</button>
        <button class="teal" data-act="museum">${text("museum")}</button>
        <button class="sun" data-act="passport">${text("passport")}</button>
        <button data-act="settings">${text("settings")}</button>
        <button data-act="parents">${text("parents")}</button>
        <div class="row">
          <button data-act="lang" data-arg="tr" class="${lang() === "tr" ? "primary" : ""}">${text("lang_tr")}</button>
          <button data-act="lang" data-arg="en" class="${lang() === "en" ? "primary" : ""}">${text("lang_en")}</button>
        </div>
      </section>`;
  }

  function showSites() {
    state.screen = "sites";
    const cards = sites.map((site, index) => {
      const open = siteUnlocked(index, sites, save);
      const stars = open ? starsFor(runtimeSpots(site.id)) : 0;
      const name = pick(lang(), site.name);
      const biome = pick(lang(), catalog.biomes.find((item) => item.id === site.biome));
      return `<button data-act="dig" data-arg="${site.id}" ${open ? "" : "disabled"} class="${open ? "primary" : ""}">
        <strong>${name}</strong><span>${biome} ${open ? "★".repeat(stars) : text("locked")}</span>
      </button>${open ? "" : `<p class="hint">${text("site_locked")}</p>`}`;
    }).join("");
    ui.innerHTML = `<section class="card wide"><h1>${text("choose_site")}</h1><div class="stack">${cards}</div><button data-act="menu">${text("back")}</button></section>`;
  }

  function enterDig(framed = false) {
    state.screen = "dig";
    const site = siteById(state.siteId);
    clearScene(view.scene);
    const dressed = dressWorld(view.scene, site.biome, { quality: save.settings.quality, siteId: site.id });
    state.sun = dressed.sun;
    addProps(view.scene, site, save.settings.quality);
    state.spots = runtimeSpots(site.id);
    state.groups = new Map();
    for (const spot of state.spots) {
      const group = addSpot(view.scene, spot, save.settings.colorblind);
      state.groups.set(spot.bone, group);
      refreshSpotVisual(spot);
    }
    state.player = buildExplorer();
    const spawn = site.spawn || [0, 2];
    const stand = view.scene.userData.sample || (() => 0);
    state.player.position.set(spawn[0], stand(spawn[0], spawn[1]), spawn[1]);
    if (framed && state.spots[0]) {
      const sx = state.spots[0].pos[0] - 1.2;
      const sz = state.spots[0].pos[1] - 0.4;
      state.player.position.set(sx, stand(sx, sz), sz);
      state.near = state.spots[0];
    }
    view.scene.add(state.player);
    state.pati = buildPati();
    state.pati.position.copy(state.player.position).add(new THREE.Vector3(-1.2, 0, 0.6));
    view.scene.add(state.pati);
    state.dust = makeDust();
    view.scene.add(state.dust);
    state.dino = null;
    state.tutorial = site.tutorial && !save.tutorialDone ? 0 : 99;
    if (state.tutorial === 0) audio.speak(text("t0"), lang());
    renderDigHud();
  }

  function renderDigHud() {
    const tools = catalog.tools.map((tool) => `<button data-tool="${tool.id}" class="tool ${tool.id === state.tool ? "on" : ""}" style="--tint:${tool.tint}">${pick(lang(), tool)}</button>`).join("");
    ui.innerHTML = `
      <div class="topbar"><strong data-site></strong><div><button data-act="passport">${text("passport")}</button><button data-act="menu">${text("menu")}</button></div></div>
      <p class="toast" data-toast></p>
      <section class="tutorial" data-tutorial><b>${text("pati_name")}</b> <span data-ttext></span> <button data-act="skip">${text("tutorial_skip")}</button></section>
      <section class="soil" data-soil>
        <div class="badge" data-badge></div>
        <div><strong data-soil-name></strong><p data-soil-feel></p><div class="bar"><i data-bar></i></div><button data-act="hint">${text("hint")}</button></div>
      </section>
      <button class="museum-go" data-act="museum-now">${text("enter_museum")}</button>
      <div class="joy" data-joy><i></i></div>
      <div class="tools">${tools}</div>
      <button class="dig" data-dig>${text("dig")}</button>
      <button class="detector" data-act="detect">${text("detector")}</button>`;
    patchDigHud();
  }

  function patchDigHud() {
    const site = siteById(state.siteId);
    setText("[data-site]", `${pick(lang(), site.name)}  ${"★".repeat(starsFor(state.spots))}`);
    const soilBox = ui.querySelector("[data-soil]");
    if (soilBox) soilBox.hidden = !state.near;
    const tent = site.tent || [-6, 0];
    const nearTent = state.player && state.player.position.distanceTo(new THREE.Vector3(tent[0], 0, tent[1])) < 2.5;
    const museumBtn = ui.querySelector("[data-act='museum-now']");
    if (museumBtn) museumBtn.hidden = !nearTent;
    if (state.near) {
      const layer = state.near.layers[state.near.layer];
      const soil = layer ? catalog.soils.find((item) => item.id === layer.soil) : null;
      setText("[data-soil-name]", soil ? pick(lang(), soil) : "");
      setText("[data-soil-feel]", soil ? text(`feel_${soil.feel}`) : "");
      const bar = ui.querySelector("[data-bar]");
      if (bar) bar.style.width = `${(state.near.progress || 0) * 100}%`;
      const badge = ui.querySelector("[data-badge]");
      if (badge) badge.dataset.icon = soil?.icon || "pile";
    }
    const tutorial = ui.querySelector("[data-tutorial]");
    if (tutorial) {
      tutorial.hidden = state.tutorial > 6;
      setText("[data-ttext]", state.tutorial <= 6 ? text(`t${state.tutorial}`) : "");
    }
    const detector = ui.querySelector("[data-act='detect']");
    if (detector) detector.textContent = state.detector > 0 ? `${text("detector")} ${Math.ceil(state.detector)}` : text("detector");
    ui.querySelectorAll("[data-tool]").forEach((button) => button.classList.toggle("on", button.dataset.tool === state.tool));
  }

  function updateTutorial() {
    if (state.tutorial === 0 && state.moved > 0.4) state.tutorial = 1;
    else if (state.tutorial === 1 && state.moved > 1.2) state.tutorial = 2;
    else if (state.tutorial === 2 && state.near?.bone === "skull") state.tutorial = 3;
    else if (state.tutorial === 3 && state.tool === "shovel" && state.near) state.tutorial = 4;
  }

  function enterMuseum(siteId) {
    state.screen = "museum";
    state.siteId = siteId;
    const site = siteById(siteId);
    const info = dinoById(site.dino);
    clearScene(view.scene);
    dressRoom(view.scene, save.settings.quality);
    state.spots = runtimeSpots(siteId);
    state.dino = buildDino(info, "ghost", save.settings.quality);
    state.dino.position.set(0, 0.05, 0);
    state.dino.rotation.y = 0.5;
    state.dino.scale.multiplyScalar(1.15);
    view.scene.add(state.dino);
    for (const spot of state.spots) setBoneState(state.dino, spot.bone, spot.placed ? "fossil" : "ghost");
    state.player = null;
    view.camera.position.set(0.4, 2.35, 6.5);
    view.camera.lookAt(0, 1.15, 0);
    const cards = info.bones.map((bone) => {
      const spot = state.spots.find((item) => item.bone === bone.id);
      const cls = spot?.placed ? "good" : spot?.collected ? "primary" : "";
      const extra = spot?.placed ? text("placed") : spot?.collected ? "" : text("not_found");
      return `<button class="bone ${cls}" data-bone="${bone.id}">${pick(lang(), bone)}${extra ? `<small>${extra}</small>` : ""}</button>`;
    }).join("");
    ui.innerHTML = `
      <div class="topbar"><strong>${pick(lang(), info.name)}</strong><div><button data-act="dig" data-arg="${siteId}">${text("resume_dig")}</button><button data-act="menu">${text("back")}</button></div></div>
      <p class="toast" data-toast>${text("drag_help")}</p>
      <div class="tray">${cards}</div>
      <div class="side">
        <button class="sun" data-act="museum-hint">${text("hint")}</button>
        <button class="good" data-act="reveal" ${allPlaced(state.spots) ? "" : "disabled"}>${text("bring_life")}</button>
      </div>`;
  }

  function enterReveal(siteId) {
    state.screen = "reveal";
    state.siteId = siteId;
    state.revealAge = 0;
    state.spoke = false;
    const site = siteById(siteId);
    const info = dinoById(site.dino);
    clearScene(view.scene);
    dressWorld(view.scene, site.biome, { plain: true, quality: save.settings.quality, siteId: site.id });
    state.dino = buildDino(info, "living", save.settings.quality);
    state.dino.scale.multiplyScalar(info.id === "velociraptor" ? 1.7 : 1.35);
    state.dino.rotation.y = Math.PI * 0.85;
    view.scene.add(state.dino);
    state.dino.userData.baseY = 0;
    view.camera.position.set(3.6, 1.9, 6.2);
    view.camera.lookAt(0, 0.9, 0.4);
    const food = new THREE.Group();
    food.position.set(1.6, 0, -0.2);
    if (info.diet === "herbivore") {
      for (let i = 0; i < 5; i += 1) {
        const leaf = new THREE.Mesh(new THREE.SphereGeometry(0.22, 12, 10), new THREE.MeshStandardMaterial({ color: "#3f8f4e" }));
        leaf.position.set(Math.sin(i) * 0.25, 0.35, Math.cos(i) * 0.2);
        food.add(leaf);
      }
    } else {
      const plate = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.4, 0.08, 20), new THREE.MeshStandardMaterial({ color: "#f4efe6" }));
      plate.position.y = 0.2;
      food.add(plate);
      const meat = new THREE.Mesh(new THREE.CapsuleGeometry(0.12, 0.28, 4, 8), new THREE.MeshStandardMaterial({ color: "#c46a4a" }));
      meat.rotation.z = 1.1;
      meat.position.y = 0.38;
      food.add(meat);
    }
    view.scene.add(food);
    const spotSave = save.sites[siteId] || {};
    if (!spotSave.revealed) {
      save.sites[siteId] = { ...spotSave, revealed: true };
      award("roar");
      awardBiome(site.biome);
      if (sites.every((item) => save.sites[item.id]?.revealed)) award("passport");
      const index = sites.findIndex((item) => item.id === siteId);
      if (index >= 0 && sites[index + 1]) say(text("unlocked_site"));
      writeSave();
    }
    audio.play("star");
    const stars = starsFor(state.spots.length ? state.spots : runtimeSpots(siteId));
    ui.innerHTML = `
      <div class="reveal-copy">
        <h1>${text("hello_dino", { name: pick(lang(), info.name) })}</h1>
        <p>${text(info.diet === "herbivore" ? "diet_herb" : "diet_carn")} ${"★".repeat(Math.max(stars, 1))}</p>
        <p class="fact" data-sub>${text("wake_line", { name: pick(lang(), info.name) })}</p>
      </div>
      <div class="tray">
        <button data-act="menu">${text("menu")}</button>
        <button data-act="museum">${text("museum")}</button>
        <button class="primary" data-act="next">${text("next_site")}</button>
        <button class="sun" data-act="roar">${text("roar")}</button>
      </div>`;
  }

  function showPassport() {
    state.screen = "passport";
    if (!state.dino) buildVista(sites[0].id);
    const cards = sites.map((site) => {
      const info = dinoById(site.dino);
      const awake = Boolean(save.sites[site.id]?.revealed);
      const fact = awake ? pick(lang(), info.facts[0]) : text("passport_empty");
      return `<article class="pass ${awake ? "awake" : ""}"><h2>${pick(lang(), info.name)}</h2><p>${pick(lang(), site.name)}</p><p>${fact}</p></article>`;
    }).join("");
    const stickers = catalog.stickers.map((item) => `<span class="sticker ${save.stickers.includes(item.id) ? "owned" : ""}">${save.stickers.includes(item.id) ? pick(lang(), item) : "·"}</span>`).join("");
    ui.innerHTML = `<section class="card wide scroll"><h1>${text("passport")}</h1><div class="grid">${cards}</div><h2>${text("album")}</h2><div class="row wrap">${stickers}</div><button data-act="menu">${text("back")}</button></section>`;
  }

  function showSettings() {
    state.screen = "settings";
    const s = save.settings;
    const toggle = (key, label) => `<button data-set="${key}">${label}: ${s[key] ? text("on") : text("off")}</button>`;
    ui.innerHTML = `<section class="card"><h1>${text("settings")}</h1>
      ${slider("music", text("music"), s.music)}
      ${slider("sfx", text("sfx"), s.sfx)}
      ${slider("voice", text("voice"), s.voice)}
      ${toggle("largeText", text("large_text"))}
      ${toggle("colorblind", text("colorblind"))}
      ${toggle("guideArrow", text("guide_arrow"))}
      ${toggle("effects", text("effects"))}
      <button data-quality="1">${text("quality")}: ${text(`quality_${s.quality || "medium"}`)}</button>
      ${toggle("haptics", text("haptics"))}
      <p class="hint">${text("save_note")}</p>
      <button data-act="menu">${text("back")}</button></section>`;
  }

  function showGate() {
    const a = 2 + Math.floor(Math.random() * 7);
    const b = 2 + Math.floor(Math.random() * 7);
    state.gate = { answer: a + b, buffer: "" };
    ui.innerHTML = `<section class="card"><h1>${text("parent_gate")}</h1><p>${text("gate_prompt", { a, b })}</p><p class="sum" data-sum></p><div class="keys">${[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => `<button data-digit="${n}">${n}</button>`).join("")}</div><button data-act="menu">${text("back")}</button></section>`;
  }

  function showParental() {
    state.screen = "settings";
    const current = save.settings.sessionMinutes;
    ui.innerHTML = `<section class="card"><h1>${text("parents")}</h1><p>${text("parent_note")}</p>
      <div class="row wrap">
        ${[0, 15, 30, 45].map((mins) => `<button data-session="${mins}" class="${current === mins ? "primary" : ""}">${mins === 0 ? text("unlimited") : `${mins} ${text("minutes")}`}</button>`).join("")}
      </div>
      <button class="primary" data-act="reset">${text("reset_progress")}</button>
      <button data-act="menu">${text("back")}</button></section>`;
  }

  function showBreak() {
    ui.innerHTML = `<section class="card break"><h1>${text("break_title")}</h1><p>${text("break_body")}</p><button class="primary" data-act="extend">${text("continue_parent")}</button><button data-act="menu">${text("end_session")}</button></section>`;
  }

  function onPointerDown(event) {
    const joy = event.target.closest("[data-joy]");
    if (joy) {
      joy.setPointerCapture?.(event.pointerId);
      moveJoy(joy, event);
      return;
    }
    const dig = event.target.closest("[data-dig]");
    if (dig) {
      state.holding = true;
      state.holdLocked = false;
      return;
    }
    const tool = event.target.closest("[data-tool]");
    if (tool) {
      selectTool(tool.dataset.tool);
      return;
    }
    const bone = event.target.closest("[data-bone]");
    if (bone && state.screen === "museum") beginDrag(bone.dataset.bone, event);
    const act = event.target.closest("[data-act]");
    if (act) runAct(act.dataset.act, act.dataset.arg);
    const digit = event.target.closest("[data-digit]");
    if (digit && state.gate) pressDigit(digit.dataset.digit);
    const quality = event.target.closest("[data-quality]");
    if (quality) {
      const order = ["low", "medium", "high"];
      const current = order.indexOf(save.settings.quality || "medium");
      save.settings.quality = order[(current + 1) % order.length];
      writeSave();
      showSettings();
      return;
    }
    const set = event.target.closest("[data-set]");
    if (set) {
      save.settings[set.dataset.set] = !save.settings[set.dataset.set];
      applyA11y();
      audio.apply(save.settings);
      writeSave();
      showSettings();
    }
    const session = event.target.closest("[data-session]");
    if (session) {
      save.settings.sessionMinutes = Number(session.dataset.session);
      save.sessionElapsed = 0;
      writeSave();
      showParental();
    }
    const slider = event.target.closest("input[data-slider]");
    if (slider) {
      save.settings[slider.dataset.slider] = Number(slider.value) / 100;
      audio.apply(save.settings);
      writeSave();
    }
  }

  function onPointerMove(event) {
    const joy = event.target.closest?.("[data-joy]") || (state.joyPointer && ui.querySelector("[data-joy]"));
    if (event.buttons && joy && (event.target.closest?.("[data-joy]") || state.joyActive)) moveJoy(ui.querySelector("[data-joy]"), event);
    if (state.drag) {
      state.drag.x = event.clientX;
      state.drag.y = event.clientY;
    }
  }

  function onPointerUp(event) {
    state.joy.set(0, 0);
    state.joyActive = false;
    const knob = ui.querySelector("[data-joy] i");
    if (knob) knob.style.transform = "translate(-50%, -50%)";
    if (event.target?.closest?.("[data-dig]") || state.holding) state.holding = false;
    if (state.drag) dropBone(event.clientX, event.clientY);
  }

  function moveJoy(joy, event) {
    if (!joy) return;
    state.joyActive = true;
    const rect = joy.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    let dx = event.clientX - cx;
    let dy = event.clientY - cy;
    const max = rect.width * 0.34;
    const len = Math.hypot(dx, dy) || 1;
    if (len > max) {
      dx = (dx / len) * max;
      dy = (dy / len) * max;
    }
    state.joy.set(dx / max, dy / max);
    const knob = joy.querySelector("i");
    if (knob) knob.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
  }

  function runAct(act, arg) {
    audio.play("ui");
    if (act === "menu") {
      state.breakOn = false;
      showMenu();
    } else if (act === "sites") showSites();
    else if (act === "dig") {
      const id = arg || state.siteId;
      const index = sites.findIndex((site) => site.id === id);
      if (!siteUnlocked(index, sites, save)) return;
      state.siteId = id;
      enterDig();
    } else if (act === "museum" || act === "museum-now") enterMuseum(state.siteId || sites[0].id);
    else if (act === "passport") showPassport();
    else if (act === "settings") showSettings();
    else if (act === "parents") showGate();
    else if (act === "lang") {
      save.lang = arg;
      writeSave();
      showMenu();
    } else if (act === "skip") {
      state.tutorial = 99;
      save.tutorialDone = true;
      writeSave();
    } else if (act === "hint") hintSoil();
    else if (act === "detect") detect();
    else if (act === "museum-hint") hintBone();
    else if (act === "reveal") {
      if (allPlaced(state.spots)) enterReveal(state.siteId);
      else say(text("complete_to_reveal"));
    } else if (act === "next") {
      const index = sites.findIndex((site) => site.id === state.siteId);
      if (sites[index + 1]) {
        state.siteId = sites[index + 1].id;
        enterDig();
      } else showPassport();
    } else if (act === "roar") {
      state.revealAge = 8.05;
      state.spoke = false;
    } else if (act === "extend") {
      save.settings.sessionMinutes = Number(save.settings.sessionMinutes) + 15;
      state.breakOn = false;
      writeSave();
      if (state.screen === "dig") renderDigHud();
      else if (state.screen === "museum") enterMuseum(state.siteId);
      else if (state.screen === "reveal") enterReveal(state.siteId);
      else showMenu();
    } else if (act === "reset") {
      const fresh = defaultSave();
      fresh.settings = save.settings;
      fresh.lang = save.lang;
      Object.assign(save, fresh);
      save.settings = fresh.settings;
      writeSave();
      showMenu();
    }
  }

  function pressDigit(digit) {
    state.gate.buffer += digit;
    setText("[data-sum]", state.gate.buffer);
    if (state.gate.buffer.length >= 2 || Number(state.gate.buffer) > 9) {
      if (Number(state.gate.buffer) === state.gate.answer) showParental();
      else {
        setText("[data-sum]", text("math_wrong"));
        state.gate.buffer = "";
        audio.play("wrong");
      }
    }
  }

  function selectTool(id) {
    state.tool = id;
    state.holdLocked = false;
    audio.play("ui");
    if (state.tutorial === 3 && id === "shovel") state.tutorial = 4;
    patchDigHud();
  }

  function hintSoil() {
    if (!state.near) {
      say(text("far_spot"));
      return;
    }
    const layer = state.near.layers[state.near.layer];
    const soil = catalog.soils.find((item) => item.id === layer.soil);
    const line = pick(lang(), soil.hint);
    say(line);
    audio.speak(line, lang());
  }

  function detect() {
    if (state.detector > 0) {
      say(text("detector_cool"));
      return;
    }
    state.detector = 8;
    audio.play("ping");
    buzz(16);
    let found = 0;
    for (const spot of state.spots) {
      if (spot.collected || !state.player) continue;
      const dist = state.player.position.distanceTo(new THREE.Vector3(spot.pos[0], 0, spot.pos[1]));
      if (dist < 12) {
        found += 1;
        const ring = new THREE.Mesh(
          new THREE.RingGeometry(0.4, 0.55, 24),
          new THREE.MeshBasicMaterial({ color: "#7ee0ef", transparent: true, opacity: 0.8, side: THREE.DoubleSide }),
        );
        ring.rotation.x = -Math.PI / 2;
        ring.position.set(spot.pos[0], 0.12, spot.pos[1]);
        view.scene.add(ring);
        ring.userData.born = state.time;
        const grow = () => {
          const age = state.time - ring.userData.born;
          ring.scale.setScalar(1 + age * 4);
          ring.material.opacity = Math.max(0, 0.8 - age);
          if (age < 1.1) requestAnimationFrame(grow);
          else view.scene.remove(ring);
        };
        grow();
      }
    }
    say(found ? text("detector_ping") : text("detector_none"));
  }

  function beginDrag(boneId, event) {
    const spot = state.spots.find((item) => item.bone === boneId);
    if (!spot?.collected) {
      say(text("need_bones"));
      audio.play("wrong");
      return;
    }
    if (spot.placed) {
      say(text("placed"));
      return;
    }
    state.drag = { bone: boneId, x: event.clientX, y: event.clientY };
    audio.play("ui");
  }

  function dropBone(x, y) {
    const bone = state.drag?.bone;
    state.drag = null;
    if (!bone || !state.dino) return;
    let best = null;
    let bestD = 9999;
    state.dino.traverse((child) => {
      if (!child.isMesh || !child.userData.boneId) return;
      const projected = child.getWorldPosition(new THREE.Vector3()).project(view.camera);
      const sx = (projected.x * 0.5 + 0.5) * canvas.clientWidth;
      const sy = (-projected.y * 0.5 + 0.5) * canvas.clientHeight;
      const dist = Math.hypot(sx - x, sy - y);
      if (dist < bestD) {
        bestD = dist;
        best = child.userData.boneId;
      }
    });
    const limit = best === bone ? 170 : 80;
    if (best === bone && bestD <= limit) {
      const spot = state.spots.find((item) => item.bone === bone);
      spot.placed = true;
      setBoneState(state.dino, bone, "fossil");
      audio.play("snap");
      buzz(16);
      say(text("snap_ok"));
      persistSite(state.siteId);
      if (allPlaced(state.spots)) {
        award("builder");
        audio.play("star");
        say(text("all_placed"));
      }
      enterMuseum(state.siteId);
    } else if (bestD < 120) {
      say(text("snap_no"));
      audio.play("wrong");
    }
  }

  function moveProxy() {}

  function hintBone() {
    const info = dinoById(siteById(state.siteId).dino);
    for (const bone of info.bones) {
      const spot = state.spots.find((item) => item.bone === bone.id);
      if (spot?.placed) continue;
      if (!spot?.collected) {
        say(text("hint_buried"));
        return;
      }
      say(text("hint_bone", { name: pick(lang(), bone) }));
      audio.speak(text("hint_bone", { name: pick(lang(), bone) }), lang());
      state.dino.traverse((child) => {
        if (child.isMesh && child.userData.boneId === bone.id && child.material?.emissive) {
          child.material.emissiveIntensity = 0.9;
        }
      });
      return;
    }
    say(text("all_placed"));
  }

  function puff(spot, toolId) {
    const color = toolId === "spray" ? "#b7e3f5" : "#c4a574";
    const name = toolId === "brush" ? "brush" : toolId === "spray" ? "spray" : toolId === "pickaxe" ? "pick" : toolId === "chisel" ? "chisel" : "dig";
    audio.play(name);
    burstDust(state.dust, new THREE.Vector3(spot.pos[0], 0.3, spot.pos[1]), color);
    const group = state.groups.get(spot.bone);
    if (!group) return;
    const total = (spot.layer + (spot.progress || 0)) / spot.layers.length;
    group.userData.mound.scale.y = Math.max(0.15, 0.5 - total * 0.35);
    group.userData.hole.visible = total > 0.05;
    group.userData.hole.scale.setScalar(0.6 + total);
    refreshSpotVisual(spot);
  }

  function refreshSpotVisual(spot) {
    const group = state.groups.get(spot.bone);
    if (!group) return;
    if (spot.collected) {
      group.userData.mound.visible = false;
      group.userData.hole.visible = true;
      group.userData.hole.scale.setScalar(1.3);
    }
    const holes = state.spots.map((item) => {
      const total = item.collected ? 1 : (item.layer + (item.progress || 0)) / item.layers.length;
      return { x: item.pos[0], z: item.pos[1], radius: 1.25, depth: total * 0.55 };
    }).filter((item) => item.depth > 0.02);
    carveTerrain(view.scene, holes);
  }

  function say(message) {
    state.toast = message;
    state.toastTime = 2.8;
    setText("[data-toast]", message);
  }

  function setText(selector, value) {
    const node = ui.querySelector(selector);
    if (node) node.textContent = value;
  }

  function runtimeSpots(siteId) {
    const site = siteById(siteId);
    const saved = save.sites[siteId]?.bones || {};
    return site.spots.map((spot) => ({
      ...spot,
      layers: spot.layers.map((layer) => ({ ...layer })),
      layer: saved[spot.bone]?.layer || 0,
      progress: saved[spot.bone]?.progress || 0,
      damage: saved[spot.bone]?.damage || 0,
      collected: Boolean(saved[spot.bone]?.collected),
      placed: Boolean(saved[spot.bone]?.placed),
    }));
  }

  function sitesBones(siteId) {
    state.spots = runtimeSpots(siteId);
    return state.spots;
  }

  function persistSpot(spot) {
    const bag = save.sites[state.siteId] || { bones: {}, revealed: false };
    bag.bones = bag.bones || {};
    bag.bones[spot.bone] = {
      layer: spot.layer,
      progress: spot.progress || 0,
      damage: spot.damage || 0,
      collected: Boolean(spot.collected),
      placed: Boolean(spot.placed),
    };
    save.sites[state.siteId] = bag;
    writeSave();
  }

  function persistSite(siteId) {
    const bag = save.sites[siteId] || { bones: {}, revealed: false };
    bag.bones = bag.bones || {};
    for (const spot of state.spots) {
      bag.bones[spot.bone] = {
        layer: spot.layer,
        progress: spot.progress || 0,
        damage: spot.damage || 0,
        collected: Boolean(spot.collected),
        placed: Boolean(spot.placed),
      };
    }
    save.sites[siteId] = bag;
    writeSave();
  }

  function prepareShotBones(siteId, placeOne) {
    const site = siteById(siteId);
    const bag = { bones: {}, revealed: false };
    site.spots.forEach((spot, index) => {
      bag.bones[spot.bone] = { collected: true, placed: placeOne && index === 0, damage: 0, layer: spot.layers.length, progress: 1 };
    });
    save.sites[siteId] = bag;
  }

  function award(id) {
    if (save.stickers.includes(id)) return;
    save.stickers.push(id);
    writeSave();
    audio.play("star");
  }

  function awardBiome(biome) {
    const group = sites.filter((site) => site.biome === biome);
    if (group.every((site) => save.sites[site.id]?.revealed)) award(biome);
  }

  function buildVista(siteId) {
    const site = siteById(siteId);
    const info = dinoById(site.dino);
    clearScene(view.scene);
    dressWorld(view.scene, site.biome, { quality: save.settings.quality, siteId: site.id });
    addProps(view.scene, site, save.settings.quality);
    state.dino = buildDino(info, "living", save.settings.quality);
    state.dino.position.set(3.6, view.scene.userData.sample?.(3.6, 2.2) || 0, 2.2);
    state.dino.rotation.y = 0.6;
    state.dino.userData.anim = "idle";
    view.scene.add(state.dino);
    state.player = buildExplorer();
    state.player.position.set(-1.4, 0, 1.2);
    view.scene.add(state.player);
  }

  function slider(key, label, value) {
    return `<label class="slider">${label}<input data-slider="${key}" type="range" min="0" max="100" value="${Math.round(value * 100)}" /></label>`;
  }

  function applyA11y() {
    document.documentElement.dataset.large = save.settings.largeText ? "1" : "0";
    document.documentElement.dataset.cb = save.settings.colorblind ? "1" : "0";
  }

  function buzz(ms) {
    if (save.settings.haptics && navigator.vibrate) navigator.vibrate(ms);
  }

  function loadSave() {
    try {
      const parsed = JSON.parse(localStorage.getItem(SAVE_KEY) || "null");
      if (!parsed) return defaultSave();
      return { ...defaultSave(), ...parsed, settings: { ...defaultSave().settings, ...(parsed.settings || {}) } };
    } catch {
      return defaultSave();
    }
  }

  function writeSave() {
    localStorage.setItem(SAVE_KEY, JSON.stringify(save));
  }
}
