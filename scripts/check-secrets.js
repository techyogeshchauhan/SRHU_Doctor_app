import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

const IGNORED_DIRS = new Set([
  '.git',
  'node_modules',
  'build',
  '.dart_tool',
  '.pub',
  '.pub-cache',
  'Pods',
  '.idea',
  '.vscode',
  'debug_out',
]);

const SENSITIVE_PATTERNS = [
  // mongodb+srv:// with actual credentials (excluding placeholders like <user>, <pass>, username:password, and JS template variables ${...})
  /mongodb\+srv:\/\/(?!<[^>]+>|\$\{)[^:]+:(?!<[^>]+>|\$\{|password|pass)[^@\s]+@[^\s\/]+/i,
  // MONGODB_PASSWORD assigned with a non-empty, non-placeholder value outside .env
  /MONGODB_PASSWORD\s*=\s*["']?(?!<[^>]+>|process\.env|\s*$)[a-zA-Z0-9_!@#$%^&*()+\-=]{3,}["']?/i,
];

function isEnvFile(filePath) {
  const base = path.basename(filePath);
  return base === '.env' || (base.startsWith('.env.') && !base.endsWith('.example'));
}

function scanDir(dir, findings) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    if (IGNORED_DIRS.has(entry.name)) continue;

    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      scanDir(fullPath, findings);
    } else if (entry.isFile()) {
      // Skip .env files since they are gitignored and legitimately hold local dev credentials
      if (isEnvFile(fullPath)) continue;

      try {
        const content = fs.readFileSync(fullPath, 'utf-8');
        const lines = content.split('\n');

        lines.forEach((line, idx) => {
          for (const pattern of SENSITIVE_PATTERNS) {
            if (pattern.test(line)) {
              findings.push({
                file: path.relative(rootDir, fullPath),
                line: idx + 1,
              });
              break;
            }
          }
        });
      } catch {
        // Skip unreadable / binary files
      }
    }
  }
}

function main() {
  const findings = [];
  scanDir(rootDir, findings);

  if (findings.length > 0) {
    console.error('\n✖ [SECRETS CHECK FAILED] Potential exposed MongoDB credentials found:');
    findings.forEach((f) => {
      console.error(`  - File: ${f.file} (Line: ${f.line})`);
    });
    console.error('\nPlease remove exposed credentials and read exclusively from environment variables.');
    process.exit(1);
  }

  console.log('✔ [SECRETS CHECK PASSED] No exposed MongoDB Atlas credentials found in codebase.');
  process.exit(0);
}

main();
