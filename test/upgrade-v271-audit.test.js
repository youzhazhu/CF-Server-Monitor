// Characterization test: documents a deployment blocker, not a migration fix.
// Run with Node >=22.13: node --test test/upgrade-v271-audit.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { initDatabase, getLatestMetrics, saveMetricsHistory } from '../src/database/schema.js';
import { updateDatabase } from '../src/database/updateDatabase.js';
import { clearServersListCache } from '../src/utils/cache.js';

test('v2.7.1 upgrade preserves old rows but leaves them invisible to v2.8.6 reads', async () => {
  const sqlite = new DatabaseSync(':memory:');
  const db = { prepare(sql) {
    const stmt = sqlite.prepare(sql); let args = [];
    return {
      bind(...values) { args = values; return this; },
      async all() { return { results: stmt.all(...args) }; },
      async first(column) { const row = stmt.get(...args); return column ? row?.[column] ?? null : row ?? null; },
      async run() { const result = stmt.run(...args); return { success: true, meta: { changes: Number(result.changes) } }; }
    };
  }};
  try {
    sqlite.exec(readFileSync(new URL('./fixtures/v2.7.1-schema.sql', import.meta.url), 'utf8'));
    sqlite.exec("INSERT INTO servers(id,name,price) VALUES('legacy','Legacy server','10/月')");
    const timestamp = Date.now() - 60_000;
    sqlite.prepare('INSERT INTO metrics_history(server_id,timestamp,cpu) VALUES(?,?,?)').run('legacy',timestamp,42);
    sqlite.exec('CREATE TABLE metrics_history_old AS SELECT * FROM metrics_history');
    await initDatabase(db);
    const result = await updateDatabase(db);
    assert.equal(result.success,true);
    assert.ok(result.results.every(r => r.success), JSON.stringify(result));
    clearServersListCache();
    const server = sqlite.prepare("SELECT * FROM servers WHERE id='legacy'").get();
    assert.equal(server.name,'Legacy server');
    assert.equal(server.history_partition_id,1);
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM metrics_history').get().n,1);
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM metrics_history_old').get().n,1);
    assert.equal(await getLatestMetrics(db,'legacy',server),null, 'Known blocker: legacy id=1 is outside new partition range');
    await saveMetricsHistory(db,'legacy',server.history_partition_id,{cpu:17},'',Date.now(),'');
    assert.equal((await getLatestMetrics(db,'legacy',server)).cpu,17);
    const second = await updateDatabase(db);
    assert.ok(second.results.every(r => r.success));
    assert.equal(second.results[0].added,0);
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM metrics_history').get().n,2);
  } finally { sqlite.close(); }
});
