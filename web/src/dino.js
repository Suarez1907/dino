import * as THREE from "three";
import { buildFossil, buildLiving, setRigQuality, stepRig } from "./dino_rig.js";

function material(color, extra = {}) {
  return new THREE.MeshStandardMaterial({
    color,
    roughness: extra.roughness ?? 0.62,
    metalness: extra.metalness ?? 0.02,
    emissive: extra.emissive ?? 0x000000,
    emissiveIntensity: extra.emissiveIntensity ?? 0,
    transparent: extra.opacity !== undefined && extra.opacity < 1,
    opacity: extra.opacity ?? 1,
  });
}

function addMesh(parent, name, boneId, geometry, pos, rot, scale, mat) {
  const mesh = new THREE.Mesh(geometry, mat);
  mesh.position.set(pos[0], pos[1], pos[2]);
  mesh.rotation.set(rot[0], rot[1], rot[2]);
  mesh.scale.set(scale[0], scale[1], scale[2]);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  mesh.userData = { part: name, boneId, baseRot: mesh.rotation.clone() };
  parent.add(mesh);
  return mesh;
}

export function buildDino(dino, mode = "living", quality = "medium") {
  if (mode === "living") return buildLiving(dino, quality);
  if (mode === "ghost" || mode === "fossil") return buildFossil(dino);
  const spec = dino.build;
  const pal = dino.palette;
  const root = new THREE.Group();
  root.scale.setScalar(spec.scale || 1);
  const ids = new Set(dino.bones.map((bone) => bone.id));
  const live = material(pal.body);
  const belly = material(pal.belly);
  const accent = material(pal.accent);
  const horn = material(pal.horn || "#f3ead4", { roughness: 0.4 });
  const fossil = material("#f3e6c4", { roughness: 0.75 });
  const ghost = material("#f4efe4", { opacity: 0.38, emissive: "#9fd6ff", emissiveIntensity: 0.35, roughness: 0.3 });
  const use = mode === "ghost" ? ghost : mode === "fossil" ? fossil : null;
  const bodyMat = use || live;
  const bellyMat = use || belly;
  const accentMat = use || accent;
  const hornMat = use || horn;
  const [bw, bh, bl] = spec.body;
  const bone = (id, fallback) => (ids.has(id) ? id : fallback);

  addMesh(root, "body", "torso", new THREE.CapsuleGeometry(Math.max(bh * 0.42, 0.12), Math.max(bl - bh, 0.2), 6, 10), [0, bh * 0.95, 0], [Math.PI / 2, 0, 0], [Math.max(bw / Math.max(bh, 0.2), 0.45), 1, 1], bodyMat);
  addMesh(root, "belly", "torso", new THREE.SphereGeometry(bh * 0.34, 16, 12), [0, bh * 0.72, 0.05], [0, 0, 0], [bw * 0.7, 0.7, bl * 0.32], bellyMat);

  const chain = spec.neckChain || 1;
  const neckBone = bone("neck", "torso");
  const neckStart = new THREE.Vector3(0, bh * 1.05, -bl * 0.42);
  const headR = spec.head;
  for (let i = 0; i < chain; i += 1) {
    const t = (i + 1) / chain;
    const pos = neckStart.clone().add(new THREE.Vector3(0, spec.neckUp * t * Math.max(bh, 0.4), -spec.neck * t * 1.7));
    addMesh(root, `neck_${i}`, neckBone, new THREE.SphereGeometry(THREE.MathUtils.lerp(bh * 0.26, headR * 0.55, t), 14, 10), [pos.x, pos.y, pos.z], [0, 0, 0], [1, 1, 1], bodyMat);
  }
  const headPos = neckStart.clone().add(new THREE.Vector3(0, spec.neckUp * Math.max(bh, 0.4), -spec.neck * 1.7));
  addMesh(root, "head", "skull", new THREE.SphereGeometry(headR, 18, 14), [headPos.x, headPos.y, headPos.z], [0, 0, 0], [1, 0.88, 1.12], bodyMat);
  addMesh(root, "snout", "skull", new THREE.SphereGeometry(headR * 0.5, 14, 10), [headPos.x, headPos.y - headR * 0.12, headPos.z - headR - spec.snout * 0.25], [0, 0, 0], [0.75, 0.5, 1.35], bodyMat);
  addMesh(root, "jaw", "skull", new THREE.BoxGeometry(headR * 0.7, headR * 0.2, spec.snout + headR * 0.45), [headPos.x, headPos.y - headR * 0.42, headPos.z - headR * 0.45], [0, 0, 0], [1, 1, 1], bellyMat);
  const eye = new THREE.SphereGeometry(headR * 0.2, 10, 8);
  const pupil = new THREE.SphereGeometry(headR * 0.09, 8, 8);
  const white = use || material("#f7f7f4", { roughness: 0.2 });
  const dark = use || material("#1c1820", { roughness: 0.15 });
  addMesh(root, "eye_l", "skull", eye, [headPos.x - headR * 0.4, headPos.y + headR * 0.16, headPos.z - headR * 0.7], [0, 0, 0], [1, 1, 1], white);
  addMesh(root, "eye_r", "skull", eye, [headPos.x + headR * 0.4, headPos.y + headR * 0.16, headPos.z - headR * 0.7], [0, 0, 0], [1, 1, 1], white);
  addMesh(root, "pupil_l", "skull", pupil, [headPos.x - headR * 0.46, headPos.y + headR * 0.14, headPos.z - headR * 0.86], [0, 0, 0], [1, 1, 1], dark);
  addMesh(root, "pupil_r", "skull", pupil, [headPos.x + headR * 0.46, headPos.y + headR * 0.14, headPos.z - headR * 0.86], [0, 0, 0], [1, 1, 1], dark);
  if (spec.teeth) {
    for (let i = 0; i < 4; i += 1) {
      const x = THREE.MathUtils.lerp(-headR * 0.22, headR * 0.22, i / 3);
      addMesh(root, `tooth_${i}`, "skull", new THREE.BoxGeometry(headR * 0.08, headR * 0.18, headR * 0.08), [headPos.x + x, headPos.y - headR * 0.25, headPos.z - headR * 1.05], [0, 0, 0], [1, 1, 1], hornMat);
    }
  }
  if (spec.frill > 0) {
    addMesh(root, "frill", bone("frill", "skull"), new THREE.SphereGeometry(spec.frill * headR, 16, 12), [headPos.x, headPos.y + headR * 0.15, headPos.z + headR * 0.45], [0.28, 0, 0], [1.35, 1.45, 0.16], accentMat);
  }
  if (spec.horns > 0) {
    const hornGeo = new THREE.CylinderGeometry(0.02, headR * 0.12, headR * 0.85, 8);
    addMesh(root, "horn_nose", "skull", hornGeo, [headPos.x, headPos.y, headPos.z - headR * 1.2], [1.2, 0, 0], [1, 1, 1], hornMat);
    if (spec.horns >= 3) {
      addMesh(root, "horn_l", "skull", hornGeo, [headPos.x - headR * 0.42, headPos.y + headR * 0.5, headPos.z - headR * 0.15], [-0.4, 0, 0.3], [1, 1.25, 1], hornMat);
      addMesh(root, "horn_r", "skull", hornGeo, [headPos.x + headR * 0.42, headPos.y + headR * 0.5, headPos.z - headR * 0.15], [-0.4, 0, -0.3], [1, 1.25, 1], hornMat);
    }
  }
  if (spec.noseBump) {
    addMesh(root, "nose", "skull", new THREE.SphereGeometry(headR * 0.28, 12, 10), [headPos.x, headPos.y + headR * 0.32, headPos.z - headR * 0.35], [0, 0, 0], [1, 1, 1], accentMat);
  }
  for (let i = 0; i < 3; i += 1) {
    const rad = THREE.MathUtils.lerp(bh * 0.26, bh * 0.07, i / 2);
    addMesh(root, `tail_${i}`, "tail", new THREE.CapsuleGeometry(Math.max(rad, 0.05), Math.max(spec.tail * 0.28, 0.15), 5, 8), [0, bh * 0.9 + i * 0.08, bl * 0.42 + i * spec.tail * 0.36], [(80 - i * 10) * Math.PI / 180, 0, 0], [1, 1, 1], bodyMat);
  }
  for (let i = 0; i < (spec.spikes || 0); i += 1) {
    const side = i % 2 === 0 ? -1 : 1;
    addMesh(root, `spike_${i}`, "tail", new THREE.CylinderGeometry(0.015, 0.07, 0.36, 6), [side * 0.18, bh * 1.02, bl * 0.55 + i * 0.16], [0, 0, side * 1.2], [1, 1, 1], accentMat);
  }
  if (spec.plates > 0) {
    const plateBone = bone("plates", "torso");
    for (let i = 0; i < spec.plates; i += 1) {
      const h = Math.max(0.28, 0.62 - Math.abs(i - spec.plates * 0.5) * 0.05);
      const z = THREE.MathUtils.lerp(-bl * 0.25, bl * 0.4, i / Math.max(spec.plates - 1, 1));
      addMesh(root, `plate_${i}`, plateBone, new THREE.ConeGeometry(0.2, h, 4), [(i % 2 === 0 ? 0.1 : -0.1), bh * 1.42, z], [0, 0.4, 0], [0.35, 1, 1], accentMat);
    }
  }
  const leg = (name, x, z, height, boneId) => {
    const pivot = new THREE.Group();
    pivot.position.set(x, height, z);
    pivot.userData = { part: name, boneId, baseRot: new THREE.Euler() };
    root.add(pivot);
    addMesh(pivot, `${name}_bone`, boneId, new THREE.CapsuleGeometry(0.1 + height * 0.08, Math.max(height * 0.55, 0.2), 5, 8), [0, -height * 0.45, 0], [0, 0, 0], [1, 1, 1], bodyMat);
    addMesh(pivot, `${name}_foot`, boneId, new THREE.SphereGeometry(0.16 + height * 0.05, 10, 8), [0, -height + 0.08, -0.08], [0, 0, 0], [1.1, 0.45, 1.3], hornMat);
  };
  const front = spec.frontLeg || 1;
  if (spec.stance === "quad") {
    leg("leg_fl", -bw * 0.32, -bl * 0.28, spec.legs * front, "leg_l");
    leg("leg_fr", bw * 0.32, -bl * 0.28, spec.legs * front, "leg_r");
    leg("leg_bl", -bw * 0.3, bl * 0.28, spec.legs * 0.92, "leg_l");
    leg("leg_br", bw * 0.3, bl * 0.28, spec.legs * 0.92, "leg_r");
  } else {
    leg("leg_l", -bw * 0.22, bl * 0.08, spec.legs, "leg_l");
    leg("leg_r", bw * 0.22, bl * 0.08, spec.legs, "leg_r");
    if (spec.claw) {
      addMesh(root, "claw_l", "leg_l", new THREE.ConeGeometry(0.05, 0.22, 6), [-bw * 0.22, 0.08, bl * 0.08 - 0.25], [1.2, 0, 0], [1, 1, 1], hornMat);
      addMesh(root, "claw_r", "leg_r", new THREE.ConeGeometry(0.05, 0.22, 6), [bw * 0.22, 0.08, bl * 0.08 - 0.25], [1.2, 0, 0], [1, 1, 1], hornMat);
    }
  }
  if (spec.arms > 0.05) {
    const armBone = bone("arm", "torso");
    const arm = (name, x) => {
      const pivot = new THREE.Group();
      pivot.position.set(x, bh * 0.95, -bl * 0.32);
      pivot.userData = { part: name, boneId: armBone, baseRot: new THREE.Euler() };
      root.add(pivot);
      addMesh(pivot, `${name}_bone`, armBone, new THREE.CapsuleGeometry(0.06 + spec.arms * 0.08, 0.18 + spec.arms * 0.35, 4, 8), [0, -0.2, -0.05], [0.3, 0, 0], [1, 1, 1], bodyMat);
    };
    arm("arm_l", -bw * 0.48);
    arm("arm_r", bw * 0.48);
    if (spec.feathers > 0) {
      addMesh(root, "feather_l", armBone, new THREE.SphereGeometry(0.16, 10, 8), [-bw * 0.62, bh * 1.05, -bl * 0.15], [0, 0, 0], [1.3, 0.35, 0.7], accentMat);
      addMesh(root, "feather_r", armBone, new THREE.SphereGeometry(0.16, 10, 8), [bw * 0.62, bh * 1.05, -bl * 0.15], [0, 0, 0], [1.3, 0.35, 0.7], accentMat);
    }
  }
  if (mode === "ghost") {
    root.traverse((child) => {
      if (child.isMesh) child.castShadow = false;
    });
  }
  root.userData.mode = mode;
  root.userData.anim = mode === "ghost" ? "ghost" : "idle";
  root.userData.baseY = 0;
  return root;
}

export function animateDino(root, time) {
  if (stepRig(root, time)) return;
  const anim = root.userData.anim || "idle";
  const walking = anim === "walk";
  const swing = walking ? Math.sin(time * 6.2) : 0;
  const set = (part, x, y = 0) => {
    root.traverse((child) => {
      if (child.userData?.part !== part || !child.userData.baseRot) return;
      child.rotation.x = child.userData.baseRot.x + x;
      child.rotation.y = child.userData.baseRot.y + y;
    });
  };
  set("leg_fl", swing * 0.5);
  set("leg_br", swing * 0.5);
  set("leg_fr", -swing * 0.5);
  set("leg_bl", -swing * 0.5);
  set("leg_l", swing * 0.5);
  set("leg_r", -swing * 0.5);
  set("arm_l", -swing * 0.35);
  set("arm_r", swing * 0.35);
  set("tail_0", 0, Math.sin(time * 1.7) * 0.2);
  set("tail_1", 0, Math.sin(time * 1.7 + 0.4) * 0.26);
  set("tail_2", 0, Math.sin(time * 1.7 + 0.8) * 0.32);
  let headX = Math.sin(time * 1.5) * 0.05;
  if (anim === "eat") headX += 0.5 + Math.sin(time * 5) * 0.15;
  if (anim === "roar") headX -= 0.32;
  set("head", headX, Math.sin(time * 0.8) * 0.08);
  const jaw = anim === "eat" ? Math.abs(Math.sin(time * 6.5)) * 0.5 : anim === "roar" ? 0.62 : 0;
  set("jaw", jaw);
  const bob = walking ? Math.abs(Math.sin(time * 6.2)) * 0.045 : Math.sin(time * 2) * 0.02;
  root.position.y = (root.userData.baseY || 0) + bob;
}

export { setRigQuality };

export function setBoneState(root, boneId, state) {
  root.traverse((child) => {
    if (!child.isMesh || child.userData.boneId !== boneId) return;
    const source = state === "fossil" ? "#f3e6c4" : state === "ghost" ? "#f4efe4" : null;
    if (!source) return;
    child.material = child.material.clone();
    child.material.color.set(source);
    child.material.transparent = state === "ghost";
    child.material.opacity = state === "ghost" ? 0.38 : 1;
    child.material.emissive.set(state === "ghost" ? "#9fd6ff" : "#000000");
    child.material.emissiveIntensity = state === "ghost" ? 0.25 : 0;
    child.castShadow = state !== "ghost";
  });
}

export function buildExplorer() {
  const group = new THREE.Group();
  const cloth = material("#3d7ea6");
  const skin = material("#f2c7a2", { roughness: 0.55 });
  const hat = material("#f2c14e");
  const pack = material("#8a5a3a");
  addMesh(group, "body", "", new THREE.CapsuleGeometry(0.28, 0.45, 6, 10), [0, 0.72, 0], [0, 0, 0], [1, 1, 1], cloth);
  addMesh(group, "head", "", new THREE.SphereGeometry(0.22, 16, 12), [0, 1.22, 0], [0, 0, 0], [1, 1, 1], skin);
  addMesh(group, "hat", "", new THREE.CylinderGeometry(0.12, 0.3, 0.16, 16), [0, 1.42, 0], [0, 0, 0], [1, 1, 1], hat);
  addMesh(group, "pack", "", new THREE.BoxGeometry(0.28, 0.32, 0.16), [0, 0.85, 0.26], [0, 0, 0], [1, 1, 1], pack);
  addMesh(group, "eye", "", new THREE.SphereGeometry(0.035, 8, 8), [-0.08, 1.26, -0.18], [0, 0, 0], [1, 1, 1], material("#1c1820"));
  addMesh(group, "eye2", "", new THREE.SphereGeometry(0.035, 8, 8), [0.08, 1.26, -0.18], [0, 0, 0], [1, 1, 1], material("#1c1820"));
  return group;
}

export function buildPati() {
  const group = new THREE.Group();
  const body = material("#f08a3c");
  addMesh(group, "body", "", new THREE.CapsuleGeometry(0.16, 0.22, 5, 8), [0, 0.28, 0], [Math.PI / 2, 0, 0], [1, 1, 1], body);
  addMesh(group, "head", "", new THREE.SphereGeometry(0.13, 12, 10), [0, 0.38, -0.18], [0, 0, 0], [1, 1, 1], material("#f6b15a"));
  addMesh(group, "eye", "", new THREE.SphereGeometry(0.03, 8, 8), [-0.05, 0.42, -0.28], [0, 0, 0], [1, 1, 1], material("#1c1820"));
  addMesh(group, "eye2", "", new THREE.SphereGeometry(0.03, 8, 8), [0.05, 0.42, -0.28], [0, 0, 0], [1, 1, 1], material("#1c1820"));
  return group;
}
