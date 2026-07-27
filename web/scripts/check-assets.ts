import { existsSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { LAYER_META } from "../src/constants";

type LayerGender = "male" | "female";

const publicRoot = resolve(import.meta.dir, "..", "public");
const layersRoot = resolve(publicRoot, "layers");
const validGenders = new Set<LayerGender>(["male", "female"]);
const expectedLayers = new Set<string>();
const errors: string[] = [];

for (const mannequin of ["mannequin_male.png", "mannequin_female.png"]) {
  if (!existsSync(resolve(publicRoot, mannequin))) {
    errors.push(`missing public/${mannequin}`);
  }
}

const paths = new Set<string>();
for (const [slot, meta] of Object.entries(LAYER_META)) {
  if (paths.has(meta.path)) {
    errors.push(`${slot} duplicates layer path ${meta.path}`);
  }
  paths.add(meta.path);

  const genders = new Set(meta.availableFor);
  if (genders.size !== meta.availableFor.length) {
    errors.push(`${slot} contains duplicate availableFor entries`);
  }

  for (const gender of genders) {
    if (!validGenders.has(gender)) {
      errors.push(`${slot} declares unsupported gender ${String(gender)}`);
      continue;
    }

    const filename = `${meta.path}_${gender}.png`;
    expectedLayers.add(filename);
    if (!existsSync(resolve(layersRoot, filename))) {
      errors.push(`${slot} declares missing public/layers/${filename}`);
    }
  }
}

for (const filename of readdirSync(layersRoot)) {
  if (filename.endsWith(".png") && !expectedLayers.has(filename)) {
    errors.push(`public/layers/${filename} exists but is not declared in LAYER_META`);
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(`[asset check] ${error}`);
  process.exit(1);
}

console.log(
  `[asset check] PASS: ${expectedLayers.size} clothing layers and 2 mannequins verified`,
);
