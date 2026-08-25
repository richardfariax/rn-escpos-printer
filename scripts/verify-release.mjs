import { appendFile, readFile } from 'node:fs/promises';

const packageJsonUrl = new URL('../package.json', import.meta.url);
const changelogUrl = new URL('../CHANGELOG.md', import.meta.url);
const packageJson = JSON.parse(await readFile(packageJsonUrl, 'utf8'));

if (typeof packageJson.name !== 'string' || packageJson.name.length === 0) {
  throw new Error('package.json must contain a non-empty package name');
}

if (
  typeof packageJson.version !== 'string' ||
  !/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(packageJson.version)
) {
  throw new Error('package.json version must be a stable SemVer value');
}

const expectedTag = `v${packageJson.version}`;
const suppliedTag = process.argv[2] ?? process.env.GITHUB_REF_NAME;

if (suppliedTag && suppliedTag !== expectedTag) {
  throw new Error(
    `Release tag ${suppliedTag} does not match package version ${packageJson.version}`
  );
}

const changelog = await readFile(changelogUrl, 'utf8');
const escapedVersion = packageJson.version.replaceAll('.', '\\.');
const changelogHeading = new RegExp(
  `^## \\[${escapedVersion}\\] - \\d{4}-\\d{2}-\\d{2}$`,
  'm'
);

if (!changelogHeading.test(changelog)) {
  throw new Error(
    `CHANGELOG.md must contain a dated [${packageJson.version}] release heading`
  );
}

if (process.env.GITHUB_OUTPUT) {
  await appendFile(
    process.env.GITHUB_OUTPUT,
    `package_name=${packageJson.name}\npackage_version=${packageJson.version}\nrelease_tag=${expectedTag}\n`
  );
}

console.log(
  `Release metadata is valid: ${packageJson.name}@${packageJson.version} (${expectedTag})`
);
