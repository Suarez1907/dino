import * as THREE from "three";

// Original kid-friendly dinosaurs. Mobile budget: about 2k triangles on the
// high mesh and about 800 on the low mesh. Both share one skeleton.
// Animations: idle, walk, eat, roar.

const SPECS = {
  triceratops: { stance: "quad", hip: 0.86, bodyL: 1.25, bodyW: 0.58, bodyH: 0.5, neck: 0.22, neckUp: 0.08, head: 0.32, snout: 0.46, tail: 0.9, leg: 0.7, arm: 0.62, frill: 0.78, horns: 3, plates: 0, spikes: 0, feathers: 0, teeth: false, nose: false, claw: false },
  velociraptor: { stance: "biped", hip: 0.78, bodyL: 0.58, bodyW: 0.22, bodyH: 0.24, neck: 0.26, neckUp: 0.2, head: 0.15, snout: 0.22, tail: 0.92, leg: 0.58, arm: 0.34, frill: 0, horns: 0, plates: 0, spikes: 0, feathers: 1, teeth: true, nose: false, claw: true },
  stegosaurus: { stance: "quad", hip: 0.92, bodyL: 1.4, bodyW: 0.5, bodyH: 0.46, neck: 0.18, neckUp: 0.02, head: 0.16, snout: 0.22, tail: 1.2, leg: 0.68, arm: 0.55, frill: 0, horns: 0, plates: 8, spikes: 4, feathers: 0, teeth: false, nose: false, claw: false },
  trex: { stance: "biped", hip: 1.28, bodyL: 1.15, bodyW: 0.52, bodyH: 0.55, neck: 0.28, neckUp: 0.2, head: 0.34, snout: 0.5, tail: 1.5, leg: 1.02, arm: 0.24, frill: 0, horns: 0, plates: 0, spikes: 0, feathers: 0, teeth: true, nose: false, claw: false },
  brachiosaurus: { stance: "quad", hip: 1.2, bodyL: 1.3, bodyW: 0.55, bodyH: 0.58, neck: 1.05, neckUp: 0.85, head: 0.18, snout: 0.24, tail: 1.05, leg: 0.95, arm: 1.15, frill: 0, horns: 0, plates: 0, spikes: 0, feathers: 0, teeth: false, nose: true, claw: false },
};

function hex(value, fallback) {
  const color = new THREE.Color(fallback);
  if (value) color.set(value);
  return color;
}

function hash3(x, y, z) {
  const n = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
  return n - Math.floor(n);
}

function framesOf(points) {
  const out = [];
  let up = new THREE.Vector3(0, 1, 0);
  for (let i = 0; i < points.length; i += 1) {
    const tangent = new THREE.Vector3();
    if (i < points.length - 1) tangent.copy(points[i + 1]).sub(points[i]);
    else tangent.copy(points[i]).sub(points[i - 1]);
    if (tangent.lengthSq() < 1e-8) tangent.set(0, 0, -1);
    tangent.normalize();
    const side = new THREE.Vector3().crossVectors(up, tangent);
    if (side.lengthSq() < 1e-6) side.set(1, 0, 0);
    side.normalize();
    const binormal = new THREE.Vector3().crossVectors(tangent, side).normalize();
    up = binormal;
    out.push({ side, binormal });
  }
  return out;
}

function pushTube(bucket, samples, sides, body, belly) {
  const frames = framesOf(samples.map((sample) => sample.p));
  const base = bucket.count;
  for (let i = 0; i < samples.length; i += 1) {
    const sample = samples[i];
    const { side, binormal } = frames[i];
    const next = samples[Math.min(i + 1, samples.length - 1)].bone;
    for (let s = 0; s < sides; s += 1) {
      const angle = (s / sides) * Math.PI * 2;
      const offset = side.clone().multiplyScalar(Math.cos(angle) * sample.rx)
        .add(binormal.clone().multiplyScalar(Math.sin(angle) * sample.ry));
      const pos = sample.p.clone().add(offset).add(binormal.clone().multiplyScalar(-sample.ry * 0.12));
      bucket.positions.push(pos.x, pos.y, pos.z);
      const bellyMix = Math.sin(angle) < -0.2 ? 1 : 0;
      const color = body.clone().lerp(belly, bellyMix);
      const mottling = 0.84 + hash3(pos.x, pos.y, pos.z) * 0.2;
      if (Math.abs(Math.sin(pos.z * 9.0 + pos.x * 3.0)) > 0.92) color.lerp(belly, 0.35);
      bucket.colors.push(color.r * mottling, color.g * mottling, color.b * mottling);
      bucket.skinIndex.push(sample.bone, next, 0, 0);
      bucket.skinWeight.push(0.78, 0.22, 0, 0);
      bucket.count += 1;
    }
  }
  for (let i = 0; i < samples.length - 1; i += 1) {
    for (let s = 0; s < sides; s += 1) {
      const s2 = (s + 1) % sides;
      const a = base + i * sides + s;
      const b = base + i * sides + s2;
      const c = base + (i + 1) * sides + s;
      const d = base + (i + 1) * sides + s2;
      bucket.indices.push(a, c, b, b, c, d);
    }
  }
}

function emptyBucket() {
  return { positions: [], colors: [], skinIndex: [], skinWeight: [], indices: [], count: 0 };
}

function geometryFrom(bucket) {
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.Float32BufferAttribute(bucket.positions, 3));
  geo.setAttribute("color", new THREE.Float32BufferAttribute(bucket.colors, 3));
  geo.setAttribute("skinIndex", new THREE.Uint16BufferAttribute(bucket.skinIndex, 4));
  geo.setAttribute("skinWeight", new THREE.Float32BufferAttribute(bucket.skinWeight, 4));
  geo.setIndex(bucket.indices);
  geo.computeVertexNormals();
  return geo;
}

function chain(points, radii, bones, steps) {
  const samples = [];
  for (let i = 0; i < points.length - 1; i += 1) {
    const last = i === points.length - 2 ? steps : steps - 1;
    for (let s = 0; s <= last; s += 1) {
      const t = s / steps;
      samples.push({
        p: points[i].clone().lerp(points[i + 1], t),
        rx: THREE.MathUtils.lerp(radii[i][0], radii[i + 1][0], t),
        ry: THREE.MathUtils.lerp(radii[i][1], radii[i + 1][1], t),
        bone: t < 0.55 ? bones[i] : bones[i + 1],
      });
    }
  }
  return samples;
}

function poseOf(spec) {
  const hips = new THREE.Vector3(0, spec.hip, 0.02);
  const spine = hips.clone().add(new THREE.Vector3(0, spec.bodyH * 0.22, -spec.bodyL * 0.22));
  const chest = hips.clone().add(new THREE.Vector3(0, spec.bodyH * 0.42, -spec.bodyL * 0.52));
  const neck = chest.clone().add(new THREE.Vector3(0, spec.neckUp * 0.55, -spec.neck));
  const head = neck.clone().add(new THREE.Vector3(0, spec.neckUp * 0.45 + spec.head * 0.15, -spec.neck * 0.85));
  const snout = head.clone().add(new THREE.Vector3(0, -spec.head * 0.08, -spec.head * 0.85 - spec.snout));
  const jaw = head.clone().add(new THREE.Vector3(0, -spec.head * 0.32, -spec.head * 0.2));
  const tail1 = hips.clone().add(new THREE.Vector3(0, 0.02, spec.bodyL * 0.42));
  const tail2 = tail1.clone().add(new THREE.Vector3(0, -0.05, spec.tail * 0.38));
  const tail3 = tail2.clone().add(new THREE.Vector3(0, -0.08, spec.tail * 0.42));
  const legX = spec.bodyW * 0.55;
  const thighL = new THREE.Vector3(-legX, hips.y - 0.02, spec.bodyL * 0.16);
  const thighR = new THREE.Vector3(legX, hips.y - 0.02, spec.bodyL * 0.16);
  const shinL = thighL.clone().add(new THREE.Vector3(0, -spec.leg * 0.48, 0.02));
  const shinR = thighR.clone().add(new THREE.Vector3(0, -spec.leg * 0.48, 0.02));
  const footL = shinL.clone().add(new THREE.Vector3(0, -spec.leg * 0.4, -0.05));
  const footR = shinR.clone().add(new THREE.Vector3(0, -spec.leg * 0.4, -0.05));
  let armL;
  let armR;
  let foreL;
  let foreR;
  if (spec.stance === "quad") {
    armL = new THREE.Vector3(-legX * 0.92, chest.y - spec.bodyH * 0.05, chest.z + 0.02);
    armR = new THREE.Vector3(legX * 0.92, chest.y - spec.bodyH * 0.05, chest.z + 0.02);
    foreL = new THREE.Vector3(armL.x, armL.y * 0.46, armL.z + 0.04);
    foreR = new THREE.Vector3(armR.x, armR.y * 0.46, armR.z + 0.04);
  } else {
    armL = new THREE.Vector3(-spec.bodyW * 0.78, chest.y - 0.02, chest.z - 0.02);
    armR = new THREE.Vector3(spec.bodyW * 0.78, chest.y - 0.02, chest.z - 0.02);
    foreL = armL.clone().add(new THREE.Vector3(0, -spec.arm * 0.7, -spec.arm * 0.25));
    foreR = armR.clone().add(new THREE.Vector3(0, -spec.arm * 0.7, -spec.arm * 0.25));
  }
  const points = {
    hips, spine, chest, neck, head, snout, jaw, tail1, tail2, tail3,
    thighL, shinL, footL, thighR, shinR, footR, armL, foreL, armR, foreR,
  };
  const lowest = Math.min(footL.y, footR.y, foreL.y, foreR.y);
  const shift = 0.05 - lowest;
  for (const point of Object.values(points)) point.y += shift;
  return points;
}

const PARENTS = {
  hips: "root", spine: "hips", chest: "spine", neck: "chest", head: "neck", jaw: "head",
  tail1: "hips", tail2: "tail1", tail3: "tail2",
  thighL: "hips", shinL: "thighL", footL: "shinL",
  thighR: "hips", shinR: "thighR", footR: "shinR",
  armL: "chest", foreL: "armL", armR: "chest", foreR: "armR",
};

function makeSkeleton(points) {
  const bones = {};
  const order = ["root", ...Object.keys(PARENTS)];
  const root = new THREE.Bone();
  root.name = "root";
  bones.root = root;
  const world = { root: new THREE.Vector3() };
  for (const name of Object.keys(PARENTS)) {
    const bone = new THREE.Bone();
    bone.name = name;
    bones[name] = bone;
    world[name] = points[name];
  }
  for (const name of Object.keys(PARENTS)) {
    const parent = bones[PARENTS[name]];
    parent.add(bones[name]);
    bones[name].position.copy(world[name].clone().sub(world[PARENTS[name]] || new THREE.Vector3()));
  }
  const list = order.map((name) => bones[name]);
  const index = Object.fromEntries(list.map((bone, i) => [bone.name, i]));
  return { root, bones, list, index };
}

function skinMaterial() {
  return new THREE.MeshStandardMaterial({
    vertexColors: true,
    roughness: 0.68,
    metalness: 0.02,
  });
}

function solidMaterial(color, roughness = 0.55) {
  return new THREE.MeshStandardMaterial({ color, roughness, metalness: 0.03 });
}

function addMesh(parent, name, geo, material) {
  const mesh = new THREE.SkinnedMesh(geo, material);
  mesh.name = name;
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  mesh.frustumCulled = false;
  parent.add(mesh);
  return mesh;
}

function ornament(parent, geo, material, position, rotation, scale) {
  const mesh = new THREE.Mesh(geo, material);
  mesh.position.copy(position);
  if (rotation) mesh.rotation.set(rotation[0], rotation[1], rotation[2]);
  if (scale) mesh.scale.set(scale[0], scale[1], scale[2]);
  mesh.castShadow = true;
  parent.add(mesh);
  return mesh;
}

function buildClips() {
  const qTrack = (name, times, eulers) => {
    const values = [];
    eulers.forEach(([x, y, z]) => {
      const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(x, y, z));
      values.push(q.x, q.y, q.z, q.w);
    });
    return new THREE.QuaternionKeyframeTrack(`${name}.quaternion`, times, values);
  };
  const idleT = [0, 1, 2];
  const idle = new THREE.AnimationClip("idle", 2, [
    qTrack("chest", idleT, [[0.03, 0, 0], [-0.03, 0, 0], [0.03, 0, 0]]),
    qTrack("head", idleT, [[0, 0.08, 0], [0.04, -0.06, 0], [0, 0.08, 0]]),
    qTrack("tail1", idleT, [[0, 0.12, 0], [0, -0.12, 0], [0, 0.12, 0]]),
    qTrack("tail2", idleT, [[0, 0.18, 0], [0, -0.18, 0], [0, 0.18, 0]]),
    qTrack("tail3", idleT, [[0, 0.24, 0], [0, -0.24, 0], [0, 0.24, 0]]),
    qTrack("jaw", idleT, [[0, 0, 0], [-0.04, 0, 0], [0, 0, 0]]),
  ]);
  const walkT = [0, 0.25, 0.5, 0.75, 1];
  const walk = new THREE.AnimationClip("walk", 1, [
    qTrack("thighL", walkT, [[0.55, 0, 0], [0.05, 0, 0], [-0.5, 0, 0], [0.05, 0, 0], [0.55, 0, 0]]),
    qTrack("thighR", walkT, [[-0.5, 0, 0], [0.05, 0, 0], [0.55, 0, 0], [0.05, 0, 0], [-0.5, 0, 0]]),
    qTrack("shinL", walkT, [[-0.15, 0, 0], [-0.7, 0, 0], [-0.2, 0, 0], [-0.15, 0, 0], [-0.15, 0, 0]]),
    qTrack("shinR", walkT, [[-0.2, 0, 0], [-0.15, 0, 0], [-0.15, 0, 0], [-0.7, 0, 0], [-0.2, 0, 0]]),
    qTrack("armL", walkT, [[-0.35, 0, 0], [0, 0, 0], [0.4, 0, 0], [0, 0, 0], [-0.35, 0, 0]]),
    qTrack("armR", walkT, [[0.4, 0, 0], [0, 0, 0], [-0.35, 0, 0], [0, 0, 0], [0.4, 0, 0]]),
    qTrack("foreL", walkT, [[-0.2, 0, 0], [-0.5, 0, 0], [-0.15, 0, 0], [-0.2, 0, 0], [-0.2, 0, 0]]),
    qTrack("foreR", walkT, [[-0.15, 0, 0], [-0.2, 0, 0], [-0.2, 0, 0], [-0.5, 0, 0], [-0.15, 0, 0]]),
    qTrack("spine", walkT, [[0, 0.06, 0], [0, 0, 0], [0, -0.06, 0], [0, 0, 0], [0, 0.06, 0]]),
    qTrack("tail1", walkT, [[0, -0.16, 0], [0, 0, 0], [0, 0.16, 0], [0, 0, 0], [0, -0.16, 0]]),
    qTrack("tail2", walkT, [[0, -0.22, 0], [0, 0, 0], [0, 0.22, 0], [0, 0, 0], [0, -0.22, 0]]),
    qTrack("hips", walkT, [[0.04, 0, 0], [-0.02, 0, 0], [0.04, 0, 0], [-0.02, 0, 0], [0.04, 0, 0]]),
  ]);
  const eatT = [0, 0.35, 0.7, 1.05, 1.4, 1.8];
  const eat = new THREE.AnimationClip("eat", 1.8, [
    qTrack("neck", eatT, [[0, 0, 0], [-0.35, 0, 0], [-0.45, 0, 0], [-0.3, 0, 0], [-0.45, 0, 0], [0, 0, 0]]),
    qTrack("head", eatT, [[0, 0, 0], [-0.45, 0, 0], [-0.6, 0, 0], [-0.35, 0, 0], [-0.55, 0, 0], [0, 0, 0]]),
    qTrack("jaw", eatT, [[0, 0, 0], [-0.15, 0, 0], [-0.55, 0, 0], [-0.08, 0, 0], [-0.5, 0, 0], [0, 0, 0]]),
  ]);
  const roarT = [0, 0.25, 0.55, 0.9, 1.35];
  const roar = new THREE.AnimationClip("roar", 1.35, [
    qTrack("neck", roarT, [[0, 0, 0], [0.2, 0, 0], [0.28, 0, 0], [0.16, 0, 0], [0, 0, 0]]),
    qTrack("head", roarT, [[0, 0, 0], [0.35, 0, 0], [0.5, 0, 0], [0.3, 0, 0], [0, 0, 0]]),
    qTrack("jaw", roarT, [[0, 0, 0], [-0.45, 0, 0], [-0.85, 0, 0], [-0.55, 0, 0], [0, 0, 0]]),
    qTrack("chest", roarT, [[0, 0, 0], [-0.06, 0, 0], [-0.1, 0, 0], [-0.04, 0, 0], [0, 0, 0]]),
    qTrack("armL", roarT, [[0, 0, 0.2], [0, 0, 0.45], [0, 0, 0.2], [0, 0, 0.4], [0, 0, 0]]),
    qTrack("armR", roarT, [[0, 0, -0.2], [0, 0, -0.45], [0, 0, -0.2], [0, 0, -0.4], [0, 0, 0]]),
  ]);
  return [idle, walk, eat, roar];
}

function decorate(spec, palette, bones) {
  const accent = solidMaterial(palette.accent, 0.48);
  const horn = solidMaterial(palette.horn, 0.38);
  const head = bones.head;
  const eyeGeo = new THREE.SphereGeometry(spec.head * 0.16, 12, 10);
  const pupilGeo = new THREE.SphereGeometry(spec.head * 0.07, 10, 8);
  const catchGeo = new THREE.SphereGeometry(spec.head * 0.03, 8, 6);
  const white = solidMaterial("#f7f4ee", 0.18);
  const dark = solidMaterial("#243044", 0.2);
  const catchMat = solidMaterial("#ffffff", 0.1);
  for (const side of [-1, 1]) {
    ornament(head, eyeGeo, white, new THREE.Vector3(side * spec.head * 0.42, spec.head * 0.08, -spec.head * 0.85));
    ornament(head, pupilGeo, dark, new THREE.Vector3(side * spec.head * 0.46, spec.head * 0.06, -spec.head * 0.98));
    ornament(head, catchGeo, catchMat, new THREE.Vector3(side * spec.head * 0.5, spec.head * 0.12, -spec.head * 1.02));
  }
  if (spec.horns > 0) {
    const cone = new THREE.ConeGeometry(spec.head * 0.12, spec.head * 0.85, 8);
    ornament(head, cone, horn, new THREE.Vector3(0, spec.head * 0.05, -spec.head * 1.35), [1.15, 0, 0]);
    if (spec.horns >= 3) {
      ornament(head, cone, horn, new THREE.Vector3(-spec.head * 0.42, spec.head * 0.55, -spec.head * 0.1), [-0.4, 0, 0.35], [1, 1.2, 1]);
      ornament(head, cone, horn, new THREE.Vector3(spec.head * 0.42, spec.head * 0.55, -spec.head * 0.1), [-0.4, 0, -0.35], [1, 1.2, 1]);
    }
  }
  if (spec.frill > 0) {
    ornament(
      head,
      new THREE.SphereGeometry(spec.head * spec.frill, 16, 12),
      accent,
      new THREE.Vector3(0, spec.head * 0.25, spec.head * 0.35),
      [0.4, 0, 0],
      [1.7, 1.45, 0.16],
    );
  }
  if (spec.nose) {
    ornament(head, new THREE.SphereGeometry(spec.head * 0.45, 12, 10), accent, new THREE.Vector3(0, spec.head * 0.35, -spec.head * 0.2));
  }
  if (spec.teeth) {
    const tooth = new THREE.ConeGeometry(spec.head * 0.06, spec.head * 0.16, 6);
    for (let i = 0; i < 5; i += 1) {
      const x = THREE.MathUtils.lerp(-spec.head * 0.28, spec.head * 0.28, i / 4);
      ornament(bones.jaw, tooth, horn, new THREE.Vector3(x, -spec.head * 0.02, -spec.snout * 0.85), [Math.PI, 0, 0]);
    }
  }
  if (spec.plates > 0) {
    for (let i = 0; i < spec.plates; i += 1) {
      const t = i / (spec.plates - 1);
      const host = t < 0.45 ? bones.spine : t < 0.75 ? bones.hips : bones.tail1;
      const h = 0.34 + Math.sin(t * Math.PI) * 0.28;
      ornament(
        host,
        new THREE.OctahedronGeometry(0.18, 0),
        accent,
        new THREE.Vector3((i % 2 === 0 ? -1 : 1) * 0.06, 0.28 + h * 0.2, THREE.MathUtils.lerp(0.2, -0.2, t)),
        [0, 0.4, 0],
        [0.28, h * 2.2, 0.7],
      );
    }
  }
  if (spec.spikes > 0) {
    const spike = new THREE.ConeGeometry(0.06, 0.32, 6);
    for (let i = 0; i < spec.spikes; i += 1) {
      const side = i % 2 === 0 ? -1 : 1;
      ornament(bones.tail2, spike, accent, new THREE.Vector3(side * 0.12, 0.08, -0.05 + i * 0.12), [0, 0, side * 1.1]);
    }
  }
  if (spec.feathers > 0) {
    const feather = new THREE.SphereGeometry(0.12, 10, 8);
    ornament(bones.armL, feather, accent, new THREE.Vector3(-0.08, -0.05, 0.02), [0.4, 0, 0.6], [1.4, 0.35, 0.9]);
    ornament(bones.armR, feather, accent, new THREE.Vector3(0.08, -0.05, 0.02), [0.4, 0, -0.6], [1.4, 0.35, 0.9]);
    ornament(bones.tail2, feather, accent, new THREE.Vector3(0, 0.08, 0.05), [0.6, 0, 0], [0.7, 0.28, 1.3]);
  }
  if (spec.claw) {
    const claw = new THREE.ConeGeometry(0.035, 0.16, 6);
    ornament(bones.footL, claw, horn, new THREE.Vector3(0, -0.02, -0.1), [1.4, 0, 0]);
    ornament(bones.footR, claw, horn, new THREE.Vector3(0, -0.02, -0.1), [1.4, 0, 0]);
  }
}

export function buildLiving(dino, quality = "medium") {
  const spec = SPECS[dino.id] || SPECS.trex;
  const palette = {
    body: hex(dino.palette?.body, "#7da86a"),
    belly: hex(dino.palette?.belly, "#f4e3bc"),
    accent: hex(dino.palette?.accent, "#e07a3d"),
    horn: hex(dino.palette?.horn, "#f3ead4"),
  };
  const points = poseOf(spec);
  const { root, bones } = makeSkeleton(points);
  const segs = quality === "low" ? 8 : 12;
  const mat = new THREE.MeshStandardMaterial({ color: palette.body, roughness: 0.62, metalness: 0.02 });
  const bellyMat = new THREE.MeshStandardMaterial({ color: palette.belly, roughness: 0.7, metalness: 0.02 });
  const group = new THREE.Group();
  group.name = dino.id;
  group.add(root);
  const bridge = (bone, child, radius, thick = 1, material = mat) => {
    if (!child || child.position.lengthSq() < 1e-6) return;
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(radius, segs, Math.max(6, segs - 2)), material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.position.copy(child.position).multiplyScalar(0.5);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), child.position.clone().normalize());
    const reach = child.position.length() / (radius * 2);
    mesh.scale.set(thick, thick * 0.86, Math.max(reach, 0.8) * 1.15);
    bone.add(mesh);
  };
  const nub = (bone, radius, pos, scale, material = mat) => {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(radius, segs, Math.max(6, segs - 2)), material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.position.copy(pos);
    if (scale) mesh.scale.set(scale[0], scale[1], scale[2]);
    bone.add(mesh);
  };
  bridge(bones.hips, bones.spine, spec.bodyH * 0.55, spec.bodyW * 1.5);
  bridge(bones.spine, bones.chest, spec.bodyH * 0.5, spec.bodyW * 1.45);
  bridge(bones.chest, bones.neck, spec.bodyH * 0.36, spec.bodyW * 1.1);
  bridge(bones.neck, bones.head, Math.max(spec.head * 0.7, spec.bodyW * 0.28), 0.95);
  bridge(bones.hips, bones.tail1, spec.bodyW * 0.42, 1.15);
  bridge(bones.tail1, bones.tail2, spec.bodyW * 0.28, 1);
  bridge(bones.tail2, bones.tail3, spec.bodyW * 0.16, 0.9);
  nub(bones.hips, spec.bodyH * 0.34, new THREE.Vector3(0, -spec.bodyH * 0.28, -spec.bodyL * 0.05), [spec.bodyW * 1.3, 0.7, spec.bodyL * 0.7], bellyMat);
  nub(bones.head, spec.head, new THREE.Vector3(0, 0.02, -spec.head * 0.15), [1.05, 0.9, 1.15]);
  nub(bones.head, spec.head * 0.46, new THREE.Vector3(0, -spec.head * 0.08, -spec.head - spec.snout * 0.55), [0.7, 0.42, 1.25]);
  nub(bones.jaw, spec.head * 0.2, new THREE.Vector3(0, -0.02, -spec.snout * 0.65), [1.05, 0.4, 1.5], bellyMat);
  for (const side of ["L", "R"]) {
    bridge(bones[`thigh${side}`], bones[`shin${side}`], spec.bodyW * 0.2, 1);
    bridge(bones[`shin${side}`], bones[`foot${side}`], spec.bodyW * 0.15, 0.9);
    nub(bones[`foot${side}`], spec.bodyW * 0.14, new THREE.Vector3(0, -0.02, -0.08), [1.2, 0.4, 1.6]);
    bridge(bones[`arm${side}`], bones[`fore${side}`], spec.stance === "quad" ? spec.bodyW * 0.16 : spec.bodyW * 0.08, 1);
    const hoof = spec.stance === "quad" ? spec.bodyW * 0.12 : spec.bodyW * 0.05;
    nub(bones[`fore${side}`], hoof, new THREE.Vector3(0, spec.stance === "quad" ? -spec.leg * 0.38 : -spec.arm * 0.4, -0.02), [1.15, 0.85, 1.3]);
  }
  decorate(spec, palette, bones);

  group.userData.clips = buildClips();
  group.userData.mixer = new THREE.AnimationMixer(group);
  group.userData.actions = {};
  for (const clip of group.userData.clips) {
    const action = group.userData.mixer.clipAction(clip);
    action.loop = THREE.LoopRepeat;
    action.clampWhenFinished = false;
    group.userData.actions[clip.name] = action;
  }
  group.userData.actions.idle.play();
  group.userData.current = "idle";
  group.userData.anim = "idle";
  group.userData.mode = "living";
  group.userData.rigged = true;
  group.userData.quality = quality;
  return group;
}

function bonePiece(from, to, radius, material) {
  const length = Math.max(from.distanceTo(to), radius * 2.2);
  const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(radius, Math.max(length - radius * 2, 0.05), 4, 8), material);
  mesh.position.copy(from).lerp(to, 0.5);
  mesh.lookAt(to);
  mesh.rotateX(Math.PI / 2);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

export function buildFossil(dino) {
  const spec = SPECS[dino.id] || SPECS.trex;
  const ids = new Set((dino.bones || []).map((bone) => bone.id));
  const points = poseOf(spec);
  const group = new THREE.Group();
  group.name = `${dino.id}_skeleton`;
  const ivory = () => new THREE.MeshStandardMaterial({
    color: "#c6b08a",
    roughness: 0.84,
    metalness: 0.02,
    transparent: true,
    opacity: 0.62,
    emissive: "#b7dcff",
    emissiveIntensity: 0,
    depthWrite: true,
  });
  const add = (boneId, mesh) => {
    mesh.userData.boneId = boneId;
    mesh.name = `${boneId}__${group.children.length}`;
    group.add(mesh);
  };
  const link = (boneId, a, b, radius) => add(boneId, bonePiece(points[a], points[b], radius, ivory()));
  const ownerArm = ids.has("arm") ? "arm" : null;
  link(ids.has("neck") ? "neck" : "torso", "chest", "neck", spec.head * 0.28);
  link(ids.has("neck") ? "neck" : "torso", "neck", "head", spec.head * 0.22);
  add("skull", bonePiece(points.head, points.snout, spec.head * 0.34, ivory()));
  add("skull", bonePiece(points.jaw, points.snout.clone().add(new THREE.Vector3(0, -0.05, 0.05)), spec.head * 0.16, ivory()));
  link("torso", "hips", "spine", spec.bodyW * 0.18);
  link("torso", "spine", "chest", spec.bodyW * 0.2);
  for (let i = 0; i < 4; i += 1) {
    const rib = new THREE.Mesh(new THREE.TorusGeometry(spec.bodyW * 0.55, 0.025, 6, 10, Math.PI), ivory());
    rib.position.copy(points.spine).lerp(points.chest, i / 3);
    rib.rotation.y = Math.PI / 2;
    rib.rotation.z = Math.PI;
    add("torso", rib);
  }
  link("tail", "hips", "tail1", spec.bodyW * 0.16);
  link("tail", "tail1", "tail2", spec.bodyW * 0.12);
  link("tail", "tail2", "tail3", spec.bodyW * 0.07);
  for (const side of ["L", "R"]) {
    const leg = side === "L" ? "leg_l" : "leg_r";
    link(leg, `thigh${side}`, `shin${side}`, spec.bodyW * 0.12);
    link(leg, `shin${side}`, `foot${side}`, spec.bodyW * 0.1);
    const armId = ownerArm || leg;
    link(armId, `arm${side}`, `fore${side}`, spec.stance === "quad" ? spec.bodyW * 0.11 : spec.bodyW * 0.06);
    const knee = points[`fore${side}`];
    const hoof = spec.stance === "quad"
      ? new THREE.Vector3(knee.x, 0.05, knee.z + 0.02)
      : knee.clone().add(new THREE.Vector3(0, -0.05, -0.08));
    add(armId, bonePiece(knee, hoof, spec.stance === "quad" ? spec.bodyW * 0.09 : spec.bodyW * 0.045, ivory()));
  }
  if (spec.frill > 0 && ids.has("frill")) {
    const frill = new THREE.Mesh(new THREE.SphereGeometry(spec.head * spec.frill, 14, 10), ivory());
    frill.scale.set(1.6, 1.35, 0.12);
    frill.position.copy(points.head).add(new THREE.Vector3(0, spec.head * 0.2, spec.head * 0.3));
    add("frill", frill);
  }
  if (spec.plates > 0 && ids.has("plates")) {
    for (let i = 0; i < spec.plates; i += 1) {
      const plate = new THREE.Mesh(new THREE.OctahedronGeometry(0.12, 0), ivory());
      const t = i / (spec.plates - 1);
      plate.position.copy(points.spine).lerp(points.tail1, t);
      plate.position.y += 0.35;
      plate.scale.set(0.35, 1.8, 0.8);
      add("plates", plate);
    }
  }
  group.userData.mode = "ghost";
  group.userData.anim = "ghost";
  group.userData.rigged = false;
  return group;
}

export function setRigQuality(root, quality) {
  if (!root?.userData?.rigged) return;
  root.userData.quality = quality;
  root.traverse((child) => {
    if (child.name === "body") child.visible = quality !== "low";
    if (child.name === "body_lod") child.visible = quality === "low";
  });
}

export function stepRig(root, time) {
  if (!root?.userData?.mixer) return false;
  const name = ["walk", "eat", "roar", "idle"].includes(root.userData.anim) ? root.userData.anim : "idle";
  if (root.userData.current !== name && root.userData.actions[name]) {
    const next = root.userData.actions[name];
    const prev = root.userData.actions[root.userData.current];
    next.reset().fadeIn(0.18).play();
    if (prev) prev.fadeOut(0.18);
    root.userData.current = name;
  }
  const last = root.userData.lastTime ?? time;
  let dt = time - last;
  if (dt < 0 || dt > 0.08) dt = 1 / 60;
  root.userData.lastTime = time;
  root.userData.mixer.update(dt);
  return true;
}
