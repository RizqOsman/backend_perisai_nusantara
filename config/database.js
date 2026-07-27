const initSqlJs = require("sql.js");
const fs = require("fs");
const path = require("path");

let db = null;

/**
 * Initialize SQLite database using sql.js
 * Creates the database file and tables if they don't exist
 */
async function initDatabase() {
  const dbPath = path.resolve(process.env.DB_PATH || "./data/perisai_nusantara.db");
  const dbDir = path.dirname(dbPath);

  // Buat folder data/ jika belum ada
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  const SQL = await initSqlJs();

  // Load existing database atau buat baru
  if (fs.existsSync(dbPath)) {
    const fileBuffer = fs.readFileSync(dbPath);
    db = new SQL.Database(fileBuffer);
    console.log(`SQLite Database loaded from: ${dbPath}`);
  } else {
    db = new SQL.Database();
    console.log(`SQLite Database created at: ${dbPath}`);
  }

  // Buat tabel danru jika belum ada
  db.run(`
    CREATE TABLE IF NOT EXISTS danru (
      id_danru TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_login DATETIME
    )
  `);

  // Auto-save ke file setiap kali ada perubahan
  saveDatabase();

  return db;
}

/**
 * Save database ke file
 */
function saveDatabase() {
  if (!db) return;

  const dbPath = path.resolve(process.env.DB_PATH || "./data/perisai_nusantara.db");
  const data = db.export();
  const buffer = Buffer.from(data);
  fs.writeFileSync(dbPath, buffer);
}

/**
 * Get database instance
 */
function getDb() {
  if (!db) {
    throw new Error("Database belum di-initialize! Panggil initDatabase() terlebih dahulu.");
  }
  return db;
}

module.exports = { initDatabase, getDb, saveDatabase };
