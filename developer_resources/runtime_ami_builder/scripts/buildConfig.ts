import * as fs from 'fs';
import * as path from 'path';
import { parse } from 'jsonc-parser';

const rabDir = process.env.RAB_DIR || path.join(__dirname, '..');
const cdkJsoncPath = path.join(rabDir, 'lib', 'cdk.jsonc');
const cdkJsonPath = path.join(rabDir, 'lib', 'cdk.json');

const source = fs.readFileSync(cdkJsoncPath, 'utf8');
const parsed = parse(source);
fs.writeFileSync(cdkJsonPath, JSON.stringify(parsed, null, 2));

console.log('✅ Generated cdk.json from cdk.jsonc');
