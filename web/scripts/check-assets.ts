import { existsSync, readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { LAYER_META } from "../src/constants";

type LayerGender = "male" | "female";

const publicRoot = resolve(import.meta.dir, "..", "public");
const layersRoot = resolve(publicRoot, "layers");
const validGenders = new Set<LayerGender>(["male", "female"]);
const expectedLayers = new Set<string>();
const errors: string[] = [];
const maxLayerDimension = 1024;

function readPngDimensions(path: string): { width: number; height: number } {
  const header = readFileSync(path).subarray(0, 24);
  if (
    header.length < 24 ||
    header[0] !== 0x89 ||
    header.toString("ascii", 1, 4) !== "PNG" ||
    header.toString("ascii", 12, 16) !== "IHDR"
  ) {
    throw new Error("invalid PNG header");
  }

  return {
    width: header.readUInt32BE(16),
    height: header.readUInt32BE(20),
  };
}

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
    const layerPath = resolve(layersRoot, filename);
    if (!existsSync(layerPath)) {
      errors.push(`${slot} declares missing public/layers/${filename}`);
      continue;
    }

    try {
      const dimensions = readPngDimensions(layerPath);
      if (
        dimensions.width > maxLayerDimension ||
        dimensions.height > maxLayerDimension
      ) {
        errors.push(
          `${slot} layer ${filename} is ${dimensions.width}x${dimensions.height}; maximum is ${maxLayerDimension}x${maxLayerDimension}`,
        );
      }
    } catch (error) {
      errors.push(
        `${slot} layer ${filename} could not be inspected: ${error instanceof Error ? error.message : String(error)}`,
      );
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
  `[asset check] PASS: ${expectedLayers.size} clothing layers at <=${maxLayerDimension}px and 2 mannequins verified`,
);
