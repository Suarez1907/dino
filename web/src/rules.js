export function soilById(catalog, id) {
  return catalog.soils.find((soil) => soil.id === id) || null;
}

export function tapTool(spot, toolId, catalog) {
  if (spot.collected) return { type: "done" };
  const layer = spot.layers[spot.layer];
  if (!layer) return { type: "done" };
  const soil = soilById(catalog, layer.soil);
  if (toolId !== layer.tool) {
    if (soil?.fragile) {
      spot.damage = Math.min(1, (spot.damage || 0) + 0.34);
      return { type: "fragile", damage: spot.damage };
    }
    return { type: "wrong" };
  }
  return { type: "ok" };
}

export function holdDig(spot, dt) {
  if (spot.collected) return { type: "done" };
  const layer = spot.layers[spot.layer];
  if (!layer) return { type: "done" };
  const seconds = Math.max(layer.seconds || 1.5, 0.4);
  spot.progress = (spot.progress || 0) + dt / seconds;
  if (spot.progress < 1) return { type: "dig", progress: spot.progress };
  spot.progress = 0;
  spot.layer += 1;
  if (spot.layer >= spot.layers.length) {
    spot.collected = true;
    return { type: "collected", damage: spot.damage || 0 };
  }
  return { type: "next" };
}

export function starsFor(spots) {
  if (!spots.length || spots.some((spot) => !spot.collected)) return 0;
  const avg = spots.reduce((sum, spot) => sum + (spot.damage || 0), 0) / spots.length;
  if (avg <= 0.01) return 3;
  if (avg <= 0.5) return 2;
  return 1;
}

export function siteUnlocked(index, sites, save) {
  if (index <= 0) return true;
  const prev = sites[index - 1];
  return Boolean(save.sites?.[prev.id]?.revealed);
}

export function allPlaced(spots) {
  return spots.length > 0 && spots.every((spot) => spot.collected && spot.placed);
}
