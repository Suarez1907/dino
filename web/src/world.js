import * as THREE from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { SSAOPass } from "three/addons/postprocessing/SSAOPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { RGBELoader } from "three/addons/loaders/RGBELoader.js";
import sandUrl from "../../godot/assets/textures/sand.jpg";
import grassUrl from "../../godot/assets/textures/grass.jpg";
import rockUrl from "../../godot/assets/textures/rock.jpg";
import snowUrl from "../../godot/assets/textures/snow.jpg";
import skyUrl from "../../godot/assets/textures/sky.hdr";

const SKY = {
  desert: ["#74c4ef", "#ffd2a2", "#e6c48a", "#c48449"],
  forest: ["#79c0e6", "#d7efc4", "#6ea85a", "#3d6a38"],
  ice: ["#8ec6ef", "#f4fbff", "#e7f3fb", "#b7d0e2"],
};

let lookPromise = null;
let look = null;

function prepTexture(texture, color) {
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.colorSpace = color ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  texture.anisotropy = 4;
  return texture;
}

export function loadLook(renderer) {
  if (look) return Promise.resolve(look);
  if (lookPromise) return lookPromise;
  const textures = new THREE.TextureLoader();
  lookPromise = Promise.all([
    textures.loadAsync(sandUrl),
    textures.loadAsync(grassUrl),
    textures.loadAsync(rockUrl),
    textures.loadAsync(snowUrl),
    new RGBELoader().loadAsync(skyUrl),
  ]).then(([sand, grass, rock, snow, hdr]) => {
    prepTexture(sand, true);
    prepTexture(grass, true);
    prepTexture(rock, true);
    prepTexture(snow, true);
    let env = null;
    if (renderer) {
      const pmrem = new THREE.PMREMGenerator(renderer);
      env = pmrem.fromEquirectangular(hdr).texture;
      pmrem.dispose();
    }
    look = { sand, grass, rock, snow, env, hdr };
    return look;
  });
  return lookPromise;
}

export function sampleHeight(x, z, biome, siteId = "") {
  const canyon = String(siteId).includes("canyon");
  const clearing = String(siteId).includes("clearing");
  let h = 0;
  if (biome === "ice") {
    h = Math.sin(x * 0.17) * 0.32 + Math.cos(z * 0.14) * 0.26 + Math.sin((x + z) * 0.06) * 0.18;
  } else if (biome === "forest") {
    h = Math.sin(x * 0.21) * Math.cos(z * 0.18) * 0.52 + Math.sin(x * 0.07 + z * 0.05) * 0.3;
    if (clearing) h *= 0.4;
  } else {
    h = Math.sin(x * 0.15) * 0.4 + Math.cos(z * 0.2 + x * 0.04) * 0.3;
    h += Math.sin(x * 0.52) * Math.cos(z * 0.46) * 0.1;
    if (canyon) h += Math.abs(Math.sin(x * 0.33)) * 0.48;
  }
  const rock = Math.sin(x * 1.7 + z * 2.05) * Math.cos(z * 1.25 - x * 0.8);
  if (rock > 0.78) h += (rock - 0.78) * 1.6;
  return h;
}

export function createView(canvas) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.25));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(50, 1, 0.1, 160);
  camera.position.set(6, 4.2, 9);
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const ssao = new SSAOPass(scene, camera, 512, 512, 16);
  ssao.kernelRadius = 10;
  ssao.minDistance = 0.002;
  ssao.maxDistance = 0.14;
  composer.addPass(ssao);
  const bloom = new UnrealBloomPass(new THREE.Vector2(512, 512), 0.18, 0.35, 0.96);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());
  return { renderer, scene, camera, composer, ssao, bloom };
}

export function resizeView(view) {
  const canvas = view.renderer.domElement;
  const width = canvas.clientWidth || window.innerWidth;
  const height = canvas.clientHeight || window.innerHeight;
  view.renderer.setSize(width, height, false);
  view.composer.setSize(width, height);
  view.camera.aspect = width / Math.max(height, 1);
  view.camera.updateProjectionMatrix();
}

export function clearScene(scene) {
  for (const child of [...scene.children]) {
    child.traverse((obj) => {
      if (obj.geometry) obj.geometry.dispose();
      const mats = obj.material ? (Array.isArray(obj.material) ? obj.material : [obj.material]) : [];
      mats.forEach((mat) => mat.dispose?.());
    });
    scene.remove(child);
  }
  scene.userData = {};
  scene.environment = look?.env || null;
  scene.fog = null;
  scene.background = null;
}

export function applyGrade(view, settings = {}) {
  const quality = settings.quality || "medium";
  const effects = settings.effects !== false;
  const pixel = quality === "high" ? 1.6 : quality === "low" ? 1 : 1.25;
  view.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, pixel));
  view.ssao.enabled = effects && quality !== "low";
  view.bloom.strength = effects ? (quality === "high" ? 0.32 : quality === "low" ? 0 : 0.18) : 0;
  view.ssao.kernelRadius = quality === "high" ? 16 : 8;
  const map = quality === "high" ? 2048 : quality === "low" ? 512 : 1024;
  const sun = view.scene.userData.sun;
  if (sun) {
    sun.castShadow = quality !== "low";
    if (sun.shadow.mapSize.x !== map) {
      sun.shadow.mapSize.set(map, map);
      if (sun.shadow.map) sun.shadow.map.dispose();
      sun.shadow.map = null;
    }
  }
  const godray = view.scene.getObjectByName("godray");
  if (godray) godray.visible = quality === "high" && effects;
  const drift = view.scene.getObjectByName("drift");
  if (drift) drift.visible = quality !== "low";
}

function terrainMaterial(biomeId) {
  const material = new THREE.MeshStandardMaterial({
    color: "#ffffff",
    roughness: 0.94,
    metalness: 0.0,
    vertexColors: true,
  });
  if (!look) return material;
  material.onBeforeCompile = (shader) => {
    shader.uniforms.sandMap = { value: look.sand };
    shader.uniforms.grassMap = { value: look.grass };
    shader.uniforms.rockMap = { value: look.rock };
    shader.uniforms.snowMap = { value: look.snow };
    shader.uniforms.biomeId = { value: biomeId };
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vWorld; varying vec3 vWorldN;")
      .replace("#include <begin_vertex>", "#include <begin_vertex>\nvWorld = (modelMatrix * vec4(transformed, 1.0)).xyz; vWorldN = normalize(mat3(modelMatrix) * normal);");
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", "#include <common>\nuniform sampler2D sandMap; uniform sampler2D grassMap; uniform sampler2D rockMap; uniform sampler2D snowMap; uniform float biomeId; varying vec3 vWorld; varying vec3 vWorldN;")
      .replace("#include <map_fragment>", `
        vec2 tuv = vWorld.xz * 0.16;
        float slope = 1.0 - clamp(vWorldN.y, 0.0, 1.0);
        vec3 albedo = texture2D(sandMap, tuv).rgb;
        vec3 grass = texture2D(grassMap, tuv * 1.15).rgb;
        vec3 rock = texture2D(rockMap, tuv * 0.62).rgb;
        vec3 snow = texture2D(snowMap, tuv).rgb;
        float grassW = biomeId > 0.5 && biomeId < 1.5 ? 0.82 : biomeId > 1.5 && biomeId < 2.5 ? 0.12 : 0.22;
        albedo = mix(albedo, grass, grassW * (1.0 - smoothstep(0.22, 0.62, slope)) * smoothstep(-0.05, 0.28, vWorld.y));
        albedo = mix(albedo, rock, smoothstep(0.3, 0.72, slope) + (biomeId > 2.5 ? 0.28 : 0.0));
        albedo = mix(albedo, snow, (biomeId > 1.5 && biomeId < 2.5 ? 0.78 : 0.0) * smoothstep(0.12, 0.5, vWorld.y) * (1.0 - slope));
        albedo = mix(vec3(0.34, 0.2, 0.12), albedo, smoothstep(-0.6, 0.02, vWorld.y));
        diffuseColor.rgb *= albedo;
      `);
  };
  return material;
}

export function dressWorld(scene, biome, options = {}) {
  const colors = SKY[biome] || SKY.desert;
  const quality = options.quality || "medium";
  const siteId = options.siteId || "";
  const biomeId = biome === "forest" ? 1 : biome === "ice" ? 2 : String(siteId).includes("canyon") ? 3 : 0;
  if (look?.env && quality !== "low") scene.environment = look.env;
  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(96, 28, 18),
    new THREE.ShaderMaterial({
      side: THREE.BackSide,
      depthWrite: false,
      uniforms: {
        top: { value: new THREE.Color(colors[0]) },
        horizon: { value: new THREE.Color(colors[1]) },
        sunDir: { value: new THREE.Vector3(0.45, 0.62, 0.28).normalize() },
        warm: { value: quality === "low" ? 0 : 1 },
      },
      vertexShader: "varying vec3 vPos; void main(){ vPos = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }",
      fragmentShader: `
        varying vec3 vPos; uniform vec3 top; uniform vec3 horizon; uniform vec3 sunDir; uniform float warm;
        void main(){
          vec3 n = normalize(vPos);
          float h = smoothstep(-0.08, 0.55, n.y);
          vec3 col = mix(horizon, top, h);
          float sun = pow(max(dot(n, sunDir), 0.0), 48.0);
          col += vec3(1.0, 0.72, 0.38) * sun * warm;
          gl_FragColor = vec4(col, 1.0);
        }`,
    }),
  );
  sky.name = "sky";
  scene.add(sky);
  scene.fog = new THREE.FogExp2(new THREE.Color(colors[1]), quality === "low" ? 0.012 : 0.02);
  const hemi = new THREE.HemisphereLight(colors[0], colors[3], 0.72);
  scene.add(hemi);
  const sun = new THREE.DirectionalLight("#fff1d2", quality === "low" ? 1.7 : 2.25);
  sun.position.set(14, 18, 8);
  sun.castShadow = quality !== "low";
  const shadow = quality === "high" ? 2048 : 1024;
  sun.shadow.mapSize.set(shadow, shadow);
  sun.shadow.camera.near = 1;
  sun.shadow.camera.far = 50;
  sun.shadow.camera.left = -18;
  sun.shadow.camera.right = 18;
  sun.shadow.camera.top = 18;
  sun.shadow.camera.bottom = -18;
  sun.shadow.bias = -0.00035;
  scene.add(sun);
  scene.add(sun.target);
  scene.userData.sun = sun;
  const fill = new THREE.DirectionalLight("#c5dcff", 0.38);
  fill.position.set(-8, 6, -4);
  scene.add(fill);
  if (quality === "high") {
    const ray = new THREE.Mesh(
      new THREE.ConeGeometry(7, 28, 16, 1, true),
      new THREE.MeshBasicMaterial({
        color: "#ffe0a8",
        transparent: true,
        opacity: 0.045,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: THREE.AdditiveBlending,
      }),
    );
    ray.name = "godray";
    ray.position.set(6, 10, 3);
    ray.lookAt(0, 0, 4);
    ray.rotateX(Math.PI / 2);
    scene.add(ray);
  }
  if (quality !== "low") {
    const count = quality === "high" ? 140 : 70;
    const positions = new Float32Array(count * 3);
    for (let i = 0; i < count; i += 1) {
      positions[i * 3] = (Math.random() - 0.5) * 36;
      positions[i * 3 + 1] = Math.random() * 3.2;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 36;
    }
    const dust = new THREE.Points(
      new THREE.BufferGeometry().setAttribute("position", new THREE.BufferAttribute(positions, 3)),
      new THREE.PointsMaterial({ color: biome === "ice" ? "#e7f3fb" : "#e6c48a", size: 0.08, transparent: true, opacity: 0.45, depthWrite: false }),
    );
    dust.name = "drift";
    dust.frustumCulled = false;
    scene.add(dust);
  }
  if (!options.plain) {
    const seg = quality === "high" ? 88 : quality === "low" ? 36 : 60;
    const geo = new THREE.PlaneGeometry(72, 72, seg, seg);
    geo.rotateX(-Math.PI / 2);
    const pos = geo.attributes.position;
    const colorsAttr = new Float32Array(pos.count * 3);
    const base = new Float32Array(pos.count);
    for (let i = 0; i < pos.count; i += 1) {
      const y = sampleHeight(pos.getX(i), pos.getZ(i), biome, siteId);
      pos.setY(i, y);
      base[i] = y;
      colorsAttr[i * 3] = 1;
      colorsAttr[i * 3 + 1] = 1;
      colorsAttr[i * 3 + 2] = 1;
    }
    geo.setAttribute("color", new THREE.BufferAttribute(colorsAttr, 3));
    geo.computeVertexNormals();
    const ground = new THREE.Mesh(geo, terrainMaterial(biomeId));
    ground.receiveShadow = true;
    ground.name = "terrain";
    ground.userData.base = base;
    ground.userData.baseColor = colorsAttr.slice();
    scene.add(ground);
    scene.userData.terrain = ground;
    scene.userData.sample = (x, z) => sampleHeight(x, z, biome, siteId);
    scene.userData.biome = biome;
    scene.userData.siteId = siteId;
  } else {
    const ground = new THREE.Mesh(
      new THREE.CircleGeometry(28, 48),
      terrainMaterial(biomeId),
    );
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    scene.add(ground);
    scene.userData.sample = () => 0;
  }
  return { sun };
}

export function carveTerrain(scene, holes) {
  const terrain = scene.userData.terrain;
  if (!terrain) return;
  const pos = terrain.geometry.attributes.position;
  const color = terrain.geometry.attributes.color;
  const base = terrain.userData.base;
  const baseColor = terrain.userData.baseColor;
  for (let i = 0; i < pos.count; i += 1) {
    let y = base[i];
    let r = baseColor[i * 3];
    let g = baseColor[i * 3 + 1];
    let b = baseColor[i * 3 + 2];
    const x = pos.getX(i);
    const z = pos.getZ(i);
    for (const hole of holes) {
      const dist = Math.hypot(x - hole.x, z - hole.z);
      if (dist >= hole.radius) continue;
      const t = 1 - dist / hole.radius;
      y -= hole.depth * t * t;
      const mix = Math.min(0.85, t);
      r = r * (1 - mix) + 0.62 * mix;
      g = g * (1 - mix) + 0.48 * mix;
      b = b * (1 - mix) + 0.32 * mix;
    }
    pos.setY(i, y);
    color.setXYZ(i, r, g, b);
  }
  pos.needsUpdate = true;
  color.needsUpdate = true;
  terrain.geometry.computeVertexNormals();
}

export function updateAtmosphere(scene, dt) {
  const dust = scene.getObjectByName("drift");
  if (!dust?.visible) return;
  const pos = dust.geometry.attributes.position;
  for (let i = 0; i < pos.count; i += 1) {
    let y = pos.getY(i) + dt * 0.18;
    let x = pos.getX(i) + Math.sin(y * 2 + i) * dt * 0.05;
    if (y > 3.4) y = 0.15;
    pos.setXYZ(i, x, y, pos.getZ(i));
  }
  pos.needsUpdate = true;
}

export function addProps(scene, site, quality = "medium") {
  const biome = site.biome;
  const sample = scene.userData.sample || (() => 0);
  const rng = mulberry(hash(site.id));
  const count = quality === "high" ? 22 : quality === "low" ? 8 : 14;
  for (let i = 0; i < count; i += 1) {
    const x = (rng() - 0.5) * 30;
    const z = rng() * 22 - 4;
    if (Math.hypot(x, z) < 2.6) continue;
    const y = sample(x, z);
    if (biome === "forest") scene.add(tree(x, y, z, 0.85 + rng()));
    else if (biome === "ice") scene.add(crystal(x, y, z, 0.7 + rng()));
    else if (i % 2 === 0) scene.add(cactus(x, y, z, 0.7 + rng() * 0.6));
    else scene.add(rock(x, y, z, 0.45 + rng() * 0.8, biome === "desert" && String(site.id).includes("canyon")));
  }
  const tentPos = site.tent || [-6, 0];
  const tentY = sample(tentPos[0], tentPos[1]);
  scene.add(tent(tentPos[0], tentY, tentPos[1]));
  scene.add(crate(tentPos[0] + 2.1, sample(tentPos[0] + 2.1, tentPos[1] + 0.8), tentPos[1] + 0.8));
  scene.add(crate(tentPos[0] + 2.5, sample(tentPos[0] + 2.5, tentPos[1] + 1.5), tentPos[1] + 1.5, 0.55));
  if (quality !== "low") {
    scene.add(fence(tentPos[0] - 1.5, tentPos[1] + 3.2, sample));
    scene.add(grid(4.2, 6.4, sample));
  }
}

export function addSpot(scene, spot, colorblind) {
  const sample = scene.userData.sample || (() => 0);
  const y = sample(spot.pos[0], spot.pos[1]);
  const group = new THREE.Group();
  group.position.set(spot.pos[0], y, spot.pos[1]);
  const mound = new THREE.Mesh(
    new THREE.SphereGeometry(0.55, 16, 12),
    new THREE.MeshStandardMaterial({ color: spot.clue === "soil_tint" ? "#8a5436" : "#a56b45", roughness: 1 }),
  );
  mound.scale.set(1.15, spot.clue === "bump" ? 0.62 : 0.38, 1.05);
  mound.position.y = 0.08;
  mound.castShadow = true;
  mound.receiveShadow = true;
  group.add(mound);
  const hole = new THREE.Mesh(
    new THREE.CylinderGeometry(0.42, 0.28, 0.3, 16),
    new THREE.MeshStandardMaterial({ color: "#3a2418", roughness: 1 }),
  );
  hole.position.y = 0.02;
  hole.visible = false;
  group.add(hole);
  if (spot.clue === "bone_tip") {
    const tip = new THREE.Mesh(new THREE.CapsuleGeometry(0.045, 0.16, 3, 6), new THREE.MeshStandardMaterial({ color: "#f3e6c4", roughness: 0.7 }));
    tip.position.set(0.05, 0.28, 0);
    tip.rotation.set(0.4, 0.2, 0.2);
    group.add(tip);
  } else if (spot.clue === "birds") {
    const birds = new THREE.Group();
    birds.position.set(0.1, 0.5, 0.05);
    birds.add(bird(-0.12, 0));
    birds.add(bird(0.14, 0.04));
    birds.name = "birds";
    group.add(birds);
  } else if (spot.clue === "sparkle") {
    const spark = sparkle();
    spark.position.y = 0.4;
    group.add(spark);
  } else if (spot.clue === "cracks") {
    for (let i = 0; i < 3; i += 1) {
      const crack = new THREE.Mesh(new THREE.BoxGeometry(0.36, 0.02, 0.03), new THREE.MeshStandardMaterial({ color: "#4a2c1c" }));
      crack.position.y = 0.16;
      crack.rotation.y = i * 0.9;
      group.add(crack);
    }
  } else if (spot.clue === "footprint") {
    for (const side of [-0.12, 0.12]) {
      const pad = new THREE.Mesh(new THREE.SphereGeometry(0.1, 10, 8), new THREE.MeshStandardMaterial({ color: "#5a3824" }));
      pad.position.set(side, 0.12, 0.04);
      pad.scale.set(0.7, 0.15, 1.1);
      group.add(pad);
    }
  }
  const marker = new THREE.Group();
  marker.position.y = 0.95;
  const pole = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.7, 0.04), new THREE.MeshStandardMaterial({ color: "#1b1d24" }));
  marker.add(pole);
  const icon = new THREE.Mesh(
    new THREE.OctahedronGeometry(0.12),
    new THREE.MeshStandardMaterial({ color: "#ffd24a", emissive: "#ffbf1f", emissiveIntensity: 0.4 }),
  );
  icon.position.y = 0.42;
  marker.add(icon);
  marker.visible = colorblind;
  marker.name = "marker";
  group.add(marker);
  group.userData = { mound, hole, marker, spot };
  scene.add(group);
  return group;
}

export function makeDust() {
  const count = 48;
  const positions = new Float32Array(count * 3);
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  const points = new THREE.Points(
    geo,
    new THREE.PointsMaterial({ color: "#c4a574", size: 0.14, transparent: true, opacity: 0.9, depthWrite: false }),
  );
  points.userData = { life: new Float32Array(count), vel: new Float32Array(count * 3), active: false };
  points.frustumCulled = false;
  return points;
}

export function burstDust(points, origin, color) {
  points.material.color.set(color);
  points.position.copy(origin);
  points.userData.active = true;
  const pos = points.geometry.attributes.position.array;
  for (let i = 0; i < points.userData.life.length; i += 1) {
    points.userData.life[i] = 0.45 + Math.random() * 0.25;
    pos[i * 3] = (Math.random() - 0.5) * 0.2;
    pos[i * 3 + 1] = 0.2;
    pos[i * 3 + 2] = (Math.random() - 0.5) * 0.2;
    points.userData.vel[i * 3] = (Math.random() - 0.5) * 1.4;
    points.userData.vel[i * 3 + 1] = 0.8 + Math.random() * 1.4;
    points.userData.vel[i * 3 + 2] = (Math.random() - 0.5) * 1.4;
  }
  points.geometry.attributes.position.needsUpdate = true;
}

export function updateDust(points, dt) {
  if (!points.userData.active) return;
  const pos = points.geometry.attributes.position.array;
  let alive = false;
  for (let i = 0; i < points.userData.life.length; i += 1) {
    points.userData.life[i] -= dt;
    if (points.userData.life[i] <= 0) continue;
    alive = true;
    pos[i * 3] += points.userData.vel[i * 3] * dt;
    pos[i * 3 + 1] += points.userData.vel[i * 3 + 1] * dt;
    pos[i * 3 + 2] += points.userData.vel[i * 3 + 2] * dt;
    points.userData.vel[i * 3 + 1] -= 3.2 * dt;
  }
  points.geometry.attributes.position.needsUpdate = true;
  points.material.opacity = alive ? 0.85 : 0;
  if (!alive) points.userData.active = false;
}

function bird(x, z) {
  const group = new THREE.Group();
  const body = new THREE.Mesh(new THREE.SphereGeometry(0.08, 10, 8), new THREE.MeshStandardMaterial({ color: "#f2d56a" }));
  body.position.set(x, 0, z);
  group.add(body);
  const beak = new THREE.Mesh(new THREE.ConeGeometry(0.03, 0.08, 6), new THREE.MeshStandardMaterial({ color: "#e07a3d" }));
  beak.rotation.x = Math.PI / 2;
  beak.position.set(x, 0, z - 0.1);
  group.add(beak);
  return group;
}

function sparkle() {
  const count = 10;
  const positions = new Float32Array(count * 3);
  for (let i = 0; i < count; i += 1) {
    positions[i * 3] = (Math.random() - 0.5) * 0.4;
    positions[i * 3 + 1] = Math.random() * 0.4;
    positions[i * 3 + 2] = (Math.random() - 0.5) * 0.4;
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  return new THREE.Points(geo, new THREE.PointsMaterial({ color: "#fff1b0", size: 0.08, transparent: true }));
}

function tree(x, y, z, scale) {
  const group = new THREE.Group();
  group.position.set(x, y, z);
  group.scale.setScalar(scale);
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.18, 1.1, 7), new THREE.MeshStandardMaterial({ color: "#6b442c", roughness: 0.9 }));
  trunk.position.y = 0.55;
  trunk.castShadow = true;
  group.add(trunk);
  const crown = new THREE.Mesh(new THREE.IcosahedronGeometry(0.72, 1), new THREE.MeshStandardMaterial({ color: "#3c8a48", roughness: 0.82 }));
  crown.position.y = 1.45;
  crown.castShadow = true;
  group.add(crown);
  const crown2 = crown.clone();
  crown2.position.y = 1.85;
  crown2.scale.setScalar(0.72);
  group.add(crown2);
  return group;
}

function cactus(x, y, z, scale) {
  const group = new THREE.Group();
  group.position.set(x, y, z);
  group.scale.setScalar(scale);
  const mat = new THREE.MeshStandardMaterial({ color: "#6ea85a", roughness: 0.7 });
  const stem = new THREE.Mesh(new THREE.CapsuleGeometry(0.16, 0.9, 4, 8), mat);
  stem.position.y = 0.65;
  stem.castShadow = true;
  group.add(stem);
  const arm = new THREE.Mesh(new THREE.CapsuleGeometry(0.08, 0.35, 3, 6), mat);
  arm.position.set(0.22, 0.85, 0);
  arm.rotation.z = 0.8;
  arm.castShadow = true;
  group.add(arm);
  return group;
}

function rock(x, y, z, scale, dark) {
  const mesh = new THREE.Mesh(
    new THREE.DodecahedronGeometry(0.45, 0),
    new THREE.MeshStandardMaterial({ color: dark ? "#8d5a48" : "#b88858", roughness: 0.94 }),
  );
  mesh.position.set(x, y + 0.12, z);
  mesh.scale.set(scale, scale * 0.62, scale * 0.9);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function crystal(x, y, z, scale) {
  const mesh = new THREE.Mesh(
    new THREE.ConeGeometry(0.22, 1.1, 5),
    new THREE.MeshStandardMaterial({ color: "#d5f1ff", roughness: 0.12, transparent: true, opacity: 0.82, emissive: "#9fd8ff", emissiveIntensity: 0.25 }),
  );
  mesh.position.set(x, y + 0.5, z);
  mesh.scale.setScalar(scale);
  mesh.castShadow = true;
  return mesh;
}

function tent(x, y, z) {
  const group = new THREE.Group();
  group.position.set(x, y, z);
  const cloth = new THREE.Mesh(new THREE.ConeGeometry(1.55, 1.75, 8), new THREE.MeshStandardMaterial({ color: "#e07a3d", roughness: 0.72 }));
  cloth.position.y = 0.88;
  cloth.castShadow = true;
  group.add(cloth);
  const door = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.9), new THREE.MeshStandardMaterial({ color: "#5c2e22", side: THREE.DoubleSide }));
  door.position.set(0, 0.48, 1.05);
  group.add(door);
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 2.1, 6), new THREE.MeshStandardMaterial({ color: "#f2c14e" }));
  pole.position.y = 1.7;
  group.add(pole);
  const flag = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.28, 0.04), new THREE.MeshStandardMaterial({ color: "#f2c14e" }));
  flag.position.set(0.35, 2.55, 0);
  group.add(flag);
  const light = new THREE.PointLight("#ffc27a", 1.4, 8);
  light.position.set(0.8, 1.2, 0.4);
  group.add(light);
  group.userData.tent = true;
  return group;
}

function crate(x, y, z, scale = 0.7) {
  const mesh = new THREE.Mesh(
    new THREE.BoxGeometry(scale, scale * 0.8, scale),
    new THREE.MeshStandardMaterial({ color: "#8a5a32", roughness: 0.84 }),
  );
  mesh.position.set(x, y + scale * 0.4, z);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function fence(x, z, sample) {
  const group = new THREE.Group();
  const wood = new THREE.MeshStandardMaterial({ color: "#a56b3c", roughness: 0.86 });
  for (let i = 0; i < 5; i += 1) {
    const px = x + i * 0.9;
    const pz = z;
    const post = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.06, 0.9, 6), wood);
    post.position.set(px, sample(px, pz) + 0.45, pz);
    post.castShadow = true;
    group.add(post);
  }
  const rail = new THREE.Mesh(new THREE.BoxGeometry(3.6, 0.06, 0.06), wood);
  rail.position.set(x + 1.8, sample(x + 1.8, z) + 0.7, z);
  group.add(rail);
  return group;
}

function grid(x, z, sample) {
  const group = new THREE.Group();
  const rope = new THREE.MeshStandardMaterial({ color: "#f2e2b0", roughness: 0.7 });
  const y = sample(x, z);
  for (let i = 0; i < 3; i += 1) {
    for (let j = 0; j < 3; j += 1) {
      const post = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.45, 5), rope);
      post.position.set(x + i * 0.8, y + 0.22, z + j * 0.8);
      group.add(post);
    }
  }
  const line = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.02, 0.02), rope);
  line.position.set(x + 0.8, y + 0.4, z);
  group.add(line);
  const line2 = line.clone();
  line2.rotation.y = Math.PI / 2;
  line2.position.set(x, y + 0.4, z + 0.8);
  group.add(line2);
  return group;
}

function hash(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i += 1) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
  return h >>> 0;
}

function mulberry(seed) {
  let s = seed || 1;
  return () => {
    s += 0x6d2b79f5;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function dressRoom(scene, quality = "medium") {
  scene.background = new THREE.Color("#1c1816");
  scene.fog = new THREE.Fog("#2a241e", 10, 22);
  if (look?.env) scene.environment = look.env;
  const hemi = new THREE.HemisphereLight("#fff4e4", "#6a4a32", 0.35);
  scene.add(hemi);
  const spot = new THREE.SpotLight("#fff1d0", quality === "low" ? 1.4 : 2.4, 12, Math.PI / 5, 0.45, 1);
  spot.position.set(0.2, 4.4, 1.6);
  spot.target.position.set(0, 0.9, 0);
  spot.castShadow = quality !== "low";
  spot.shadow.mapSize.set(quality === "high" ? 1024 : 512, quality === "high" ? 1024 : 512);
  scene.add(spot);
  scene.add(spot.target);
  const fill = new THREE.PointLight("#ffd7a1", 2.2, 8);
  fill.position.set(-2.2, 2.4, 2);
  scene.add(fill);
  const floor = new THREE.Mesh(
    new THREE.CircleGeometry(9, 48),
    new THREE.MeshPhysicalMaterial({
      color: "#c9844a",
      roughness: 0.16,
      metalness: 0.08,
      clearcoat: quality === "low" ? 0 : 0.65,
      clearcoatRoughness: 0.22,
      envMapIntensity: 1,
    }),
  );
  floor.rotation.x = -Math.PI / 2;
  floor.receiveShadow = true;
  scene.add(floor);
  const wallMat = new THREE.MeshStandardMaterial({ color: "#f6efe2", roughness: 0.82 });
  const wall = new THREE.Mesh(new THREE.BoxGeometry(16, 5.5, 0.35), wallMat);
  wall.position.set(0, 2.6, -4.4);
  wall.receiveShadow = true;
  scene.add(wall);
  const side = new THREE.Mesh(new THREE.BoxGeometry(0.35, 5.5, 12), wallMat);
  side.position.set(-7.2, 2.6, 0.4);
  scene.add(side);
  const rug = new THREE.Mesh(new THREE.BoxGeometry(6.2, 0.05, 3.1), new THREE.MeshStandardMaterial({ color: "#1f7a8c", roughness: 0.9 }));
  rug.position.set(0, 0.03, 0.3);
  rug.receiveShadow = true;
  scene.add(rug);
  const plinth = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.7, 0.12, 20), new THREE.MeshStandardMaterial({ color: "#d7c4a3", roughness: 0.45 }));
  plinth.position.set(0, 0.06, 0);
  plinth.receiveShadow = true;
  scene.add(plinth);
}
