import assert from "node:assert/strict";
import test from "node:test";
import { allPlaced, holdDig, siteUnlocked, starsFor, tapTool } from "../src/rules.js";

const catalog = {
  soils: [
    { id: "loose", fragile: false },
    { id: "fragile", fragile: true },
  ],
};

function spot() {
  return {
    collected: false,
    damage: 0,
    layer: 0,
    progress: 0,
    layers: [
      { soil: "loose", tool: "shovel", seconds: 1 },
      { soil: "fragile", tool: "brush", seconds: 1 },
    ],
  };
}

test("wrong tool on fragile soil cracks once and does not dig", () => {
  const bone = spot();
  bone.layer = 1;
  const result = tapTool(bone, "shovel", catalog);
  assert.equal(result.type, "fragile");
  assert.ok(bone.damage > 0.3);
  assert.equal(bone.collected, false);
  assert.equal(bone.layer, 1);
});

test("correct tool completes layers and scores stars", () => {
  const bone = spot();
  assert.equal(tapTool(bone, "shovel", catalog).type, "ok");
  assert.equal(holdDig(bone, 1).type, "next");
  assert.equal(tapTool(bone, "brush", catalog).type, "ok");
  const done = holdDig(bone, 1);
  assert.equal(done.type, "collected");
  assert.equal(starsFor([bone]), 3);
  bone.damage = 0.4;
  assert.equal(starsFor([bone]), 2);
  bone.damage = 0.8;
  assert.equal(starsFor([bone]), 1);
  assert.equal(starsFor([{ collected: false }]), 0);
});

test("sites unlock after the previous dinosaur wakes", () => {
  const sites = [{ id: "a" }, { id: "b" }];
  assert.equal(siteUnlocked(0, sites, {}), true);
  assert.equal(siteUnlocked(1, sites, { sites: {} }), false);
  assert.equal(siteUnlocked(1, sites, { sites: { a: { revealed: true } } }), true);
});

test("assembly needs every collected bone placed", () => {
  assert.equal(allPlaced([{ collected: true, placed: true }, { collected: true, placed: false }]), false);
  assert.equal(allPlaced([{ collected: true, placed: true }]), true);
});
