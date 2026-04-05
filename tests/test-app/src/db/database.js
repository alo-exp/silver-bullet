const Database = require('better-sqlite3');

// Module-level singleton. Tests call resetDb() in beforeEach to close and
// re-initialize, ensuring each test starts with a fresh in-memory database.
let db;

function getDb() {
  if (!db) {
    db = new Database(':memory:');
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    initSchema(db);
  }
  return db;
}

function initSchema(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      due_date TEXT DEFAULT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  `);
}

function resetDb() {
  if (db) {
    db.close();
    db = null;
  }
}

module.exports = { getDb, resetDb };
