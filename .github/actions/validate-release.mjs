import { existsSync, readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(process.argv[2] ?? ".");
const expectedVersion = process.argv[3];
const manifestPath = resolve(root, "fxmanifest.lua");

const fail = (message) => {
  console.error(`[release validation] FAIL: ${message}`);
  process.exitCode = 1;
};

if (!existsSync(manifestPath)) {
  fail(`fxmanifest.lua is missing from ${root}`);
  process.exit();
}

const manifest = readFileSync(manifestPath, "utf8");
const uncommented = manifest.replace(/--.*$/gm, "");
const paths = new Set();

for (const blockName of [
  "shared_scripts",
  "server_scripts",
  "client_scripts",
  "files",
]) {
  const block = uncommented.match(
    new RegExp(`${blockName}\\s*\\{([\\s\\S]*?)\\}`, "m"),
  );

  if (!block) {
    fail(`manifest block ${blockName} was not found`);
    continue;
  }

  for (const match of block[1].matchAll(/["']([^"']+)["']/g)) {
    if (!match[1].startsWith("@")) paths.add(match[1]);
  }
}

const uiPage = uncommented.match(/ui_page\s*["']([^"']+)["']/m);
if (!uiPage) {
  fail("ui_page was not found in fxmanifest.lua");
} else {
  paths.add(uiPage[1]);
}

let verifiedPaths = 0;

for (const declaredPath of paths) {
  const normalizedPath = declaredPath.replaceAll("\\", "/");
  const hasGlob = /[*?[]/.test(normalizedPath);

  if (hasGlob) {
    const matches = Array.from(
      new Bun.Glob(normalizedPath).scanSync({ cwd: root, onlyFiles: true }),
    );

    if (matches.length === 0) {
      fail(`manifest pattern has no matches: ${declaredPath}`);
      continue;
    }
  } else {
    const absolutePath = resolve(root, normalizedPath);
    if (!existsSync(absolutePath) || !statSync(absolutePath).isFile()) {
      fail(`manifest file is missing: ${declaredPath}`);
      continue;
    }
  }

  verifiedPaths += 1;
}

for (const requiredPath of ["README.md", "config.lua", "fxmanifest.lua"]) {
  const absolutePath = resolve(root, requiredPath);
  if (!existsSync(absolutePath) || !statSync(absolutePath).isFile()) {
    fail(`required release file is missing: ${requiredPath}`);
  }
}

for (const forbiddenPath of [
  ".git",
  ".github",
  "web/node_modules",
  "web/src",
]) {
  if (existsSync(resolve(root, forbiddenPath))) {
    fail(`development-only path is present: ${forbiddenPath}`);
  }
}

if (expectedVersion) {
  const version = uncommented.match(/\bversion\s*["']([^"']+)["']/m)?.[1];
  if (version !== expectedVersion) {
    fail(`manifest version is ${version ?? "missing"}; expected ${expectedVersion}`);
  }
}

if (!process.exitCode) {
  console.log(
    `[release validation] PASS: ${verifiedPaths} manifest paths verified in ${root}`,
  );
}
