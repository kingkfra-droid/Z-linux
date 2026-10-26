import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(__dirname, 'data');

let _id = 0;
export function nextId() {
  return ++_id;
}

export class Store {
  constructor(name, seedData = []) {
    this.file = path.join(dataDir, `${name}.json`);
    this.name = name;
    this.data = this._load(seedData);
    // track max id
    const maxId = this.data.reduce((m, x) => Math.max(m, Number(x.id) || 0), 0);
    if (maxId > _id) _id = maxId;
  }

  _load(seed) {
    try {
      return JSON.parse(fs.readFileSync(this.file, 'utf-8'));
    } catch {
      this._save(seed);
      return JSON.parse(JSON.stringify(seed));
    }
  }

  _save(data = this.data) {
    fs.mkdirSync(dataDir, { recursive: true });
    fs.writeFileSync(this.file, JSON.stringify(data, null, 2));
  }

  all() {
    return this.data;
  }

  find(id) {
    return this.data.find((x) => String(x.id) === String(id));
  }

  filter(pred) {
    return this.data.filter(pred);
  }

  add(item) {
    if (!item.id) item.id = nextId();
    this.data.push(item);
    this._save();
    return item;
  }

  update(id, patch) {
    const item = this.find(id);
    if (!item) return null;
    Object.assign(item, patch, { updatedAt: new Date().toISOString() });
    this._save();
    return item;
  }

  remove(id) {
    const before = this.data.length;
    this.data = this.data.filter((x) => String(x.id) !== String(id));
    if (this.data.length !== before) this._save();
    return this.data.length !== before;
  }

  bulkAdd(items) {
    for (const item of items) {
      if (!item.id) item.id = nextId();
      this.data.push(item);
    }
    this._save();
    return items;
  }
}
