import * as THREE from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { SSAOPass } from "three/addons/postprocessing/SSAOPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

const SKY = {
  desert: ["#74c4ef", "#ffd2a2", "#e6c48a", "#c48449"],
  forest: ["#79c0e6", "#d7efc4", "#6ea85a", "#3d6a38"],
  ice: ["#8ec6ef", "#f4fbff", "#e7f3fb", "#b7d0e2"],
};

export function createView(canvas) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.6));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.06;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(50, 1, 0.1, 140);
  camera.position.set(6, 4.2, 9);
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const ssao = new SSAOPass(scene, camera, 512, 512, 16);
  ssao.kernelRadius = 12;
  ssao.minDistance = 0.002;
  ssao.maxDistance = 0.12;
  composer.addPass(ssao);
  const bloom = new UnrealBloomPass(new THREE.Vector2(512, 512), 0.28, 0.45, 0.86);
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
}

export function dressWorld(scene, biome, options = {}) {
  const colors = SKY[biome] || SKY.desert;
  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(90, 24, 16),
    new THREE.ShaderMaterial({
      side: THREE.BackSide,
      depthWrite: false,
      uniforms: {
        top: { value: new THREE.Color(colors[0]) },
        horizon: { value: new THREE.Color(colors[1]) },
      },
      vertexShader: "varying vec3 vPos; void main(){ vPos = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }",
      fragmentShader: "varying vec3 vPos; uniform vec3 top; uniform vec3 horizon; void main(){ float h = normalize(vPos).y; gl_FragColor = vec4(mix(horizon, top, smoothstep(-0.05, 0.55, h)), 1.0); }",
    }),
  );
  scene.add(sky);
  scene.fog = new THREE.Fog(new THREE.Color(colors[1]), 28, 78);
  const hemi = new THREE.HemisphereLight(colors[0], colors[3], 0.85);
  scene.add(hemi);
  const sun = new THREE.DirectionalLight("#fff2dc", 2.15);
  sun.position.set(12, 18, 8);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.camera.near = 1;
  sun.shadow.camera.far = 48;
  sun.shadow.camera.left = -18;
  sun.shadow.camera.right = 18;
  sun.shadow.camera.top = 18;
  sun.shadow.camera.bottom = -18;
  sun.shadow.bias = -0.0004;
  sun.shadow.radius = 2;
  scene.add(sun);
  scene.add(sun.target);
  const fill = new THREE.DirectionalLight("#c5dcff", 0.45);
  fill.position.set(-8, 6, -4);
  scene.add(fill);
  const ground = new THREE.Mesh(
    new THREE.CircleGeometry(36, 48),
    new THREE.MeshStandardMaterial({ color: colors[2], roughness: 0.95 }),
  );
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);
  if (!options.plain) {
    const patch = new THREE.Mesh(
      new THREE.CircleGeometry(10, 32),
      new THREE.MeshStandardMaterial({ color: colors[3], roughness: 1 }),
    );
    patch.rotation.x = -Math.PI / 2;
    patch.position.y = 0.01;
    patch.receiveShadow = true;
    scene.add(patch);
  }
  return { sun };
}

export function addProps(scene, site) {
  const biome = site.biome;
  const rng = mulberry(hash(site.id));
  for (let i = 0; i < 12; i += 1) {
    const x = (rng() - 0.5) * 30;
    const z = rng() * 20 - 2;
    if (Math.hypot(x, z) < 2.4) continue;
    if (biome === "forest") scene.add(tree(x, z, 0.8 + rng()));
    else if (biome === "ice") scene.add(crystal(x, z, 0.7 + rng()));
    else if (i % 2 === 0) scene.add(cactus(x, z, 0.7 + rng() * 0.6));
    else scene.add(rock(x, z, 0.5 + rng()));
  }
  const tentPos = site.tent || [-6, 0];
  scene.add(tent(tentPos[0], tentPos[1]));
}

export function addSpot(scene, spot, colorblind) {
  const group = new THREE.Group();
  group.position.set(spot.pos[0], 0, spot.pos[1]);
  const mound = new THREE.Mesh(
    new THREE.SphereGeometry(0.55, 16, 12),
    new THREE.MeshStandardMaterial({ color: spot.clue === "soil_tint" ? "#8a5436" : "#a56b45", roughness: 1 }),
  );
  mound.scale.set(1.15, spot.clue === "bump" ? 0.62 : 0.38, 1.05);
  mound.position.y = 0.12;
  mound.castShadow = true;
  mound.receiveShadow = true;
  group.add(mound);
  const hole = new THREE.Mesh(
    new THREE.CylinderGeometry(0.42, 0.28, 0.3, 16),
    new THREE.MeshStandardMaterial({ color: "#3a2418", roughness: 1 }),
  );
  hole.position.y = 0.04;
  hole.visible = false;
  group.add(hole);
  if (spot.clue === "bone_tip") {
    const tip = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.24, 0.08), new THREE.MeshStandardMaterial({ color: "#f6ead2" }));
    tip.position.set(0.05, 0.32, 0);
    tip.rotation.set(0.3, 0.4, 0.1);
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
      crack.position.y = 0.2;
      crack.rotation.y = i * 0.9;
      group.add(crack);
    }
  } else if (spot.clue === "footprint") {
    for (const side of [-0.12, 0.12]) {
      const pad = new THREE.Mesh(new THREE.SphereGeometry(0.1, 10, 8), new THREE.MeshStandardMaterial({ color: "#5a3824" }));
      pad.position.set(side, 0.16, 0.04);
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

function tree(x, z, scale) {
  const group = new THREE.Group();
  group.position.set(x, 0, z);
  group.scale.setScalar(scale);
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.18, 1.1, 8), new THREE.MeshStandardMaterial({ color: "#7a4e32", roughness: 0.9 }));
  trunk.position.y = 0.55;
  trunk.castShadow = true;
  group.add(trunk);
  const crown = new THREE.Mesh(new THREE.SphereGeometry(0.7, 14, 12), new THREE.MeshStandardMaterial({ color: "#3f8f4e", roughness: 0.8 }));
  crown.position.y = 1.45;
  crown.castShadow = true;
  group.add(crown);
  return group;
}

function cactus(x, z, scale) {
  const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(0.16, 0.9, 4, 8), new THREE.MeshStandardMaterial({ color: "#6ea85a", roughness: 0.7 }));
  mesh.position.set(x, 0.65, z);
  mesh.scale.setScalar(scale);
  mesh.castShadow = true;
  return mesh;
}

function rock(x, z, scale) {
  const mesh = new THREE.Mesh(new THREE.DodecahedronGeometry(0.45, 0), new THREE.MeshStandardMaterial({ color: "#b88858", roughness: 0.92 }));
  mesh.position.set(x, 0.22, z);
  mesh.scale.set(scale, scale * 0.6, scale);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function crystal(x, z, scale) {
  const mesh = new THREE.Mesh(
    new THREE.ConeGeometry(0.22, 1.1, 5),
    new THREE.MeshStandardMaterial({ color: "#d5f1ff", roughness: 0.15, transparent: true, opacity: 0.82, emissive: "#9fd8ff", emissiveIntensity: 0.25 }),
  );
  mesh.position.set(x, 0.5, z);
  mesh.scale.setScalar(scale);
  mesh.castShadow = true;
  return mesh;
}

function tent(x, z) {
  const group = new THREE.Group();
  group.position.set(x, 0, z);
  const cloth = new THREE.Mesh(new THREE.ConeGeometry(1.5, 1.7, 7), new THREE.MeshStandardMaterial({ color: "#e07a3d", roughness: 0.75 }));
  cloth.position.y = 0.85;
  cloth.castShadow = true;
  group.add(cloth);
  const flag = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.28, 0.05), new THREE.MeshStandardMaterial({ color: "#f2c14e" }));
  flag.position.set(0.35, 1.85, 0);
  group.add(flag);
  const light = new THREE.PointLight("#ffc27a", 1.2, 7);
  light.position.set(0.8, 1.2, 0.4);
  group.add(light);
  group.userData.tent = true;
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
