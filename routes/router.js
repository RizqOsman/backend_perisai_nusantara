// routes/router.js

const express = require("express");
const router = express.Router();

const bcrypt = require("bcryptjs");
const { v4: uuidv4 } = require("uuid");
const jwt = require("jsonwebtoken");

const { getDb, saveDatabase } = require("../config/database.js");
const userMiddleware = require("../middleware/users.js");

// ============================================================
// POST /sign-up - Registrasi user baru
// ============================================================
router.post("/sign-up", userMiddleware.validateRegister, async (req, res) => {
  try {
    const db = getDb();
    const { email, password, name } = req.body;

    // Cek apakah email sudah terdaftar
    const existing = db.exec(
      `SELECT * FROM danru WHERE email = ?`,
      [email]
    );

    if (existing.length > 0 && existing[0].values.length > 0) {
      return res.status(409).json({
        msg: "Email sudah terdaftar!",
      });
    }

    // Hash password
    const hash = await bcrypt.hash(password, 10);

    // Insert user baru
    const id = uuidv4();
    db.run(
      `INSERT INTO danru (id_danru, email, password, name) VALUES (?, ?, ?, ?)`,
      [id, email, hash, name]
    );

    // Simpan ke file
    saveDatabase();

    return res.status(201).json({
      msg: "Registrasi berhasil!",
      user: {
        id_danru: id,
        email: email,
        name: name,
      },
    });
  } catch (err) {
    console.error("Error sign-up:", err);
    return res.status(500).json({
      msg: "Terjadi kesalahan saat registrasi",
      error: err.message,
    });
  }
});

// ============================================================
// POST /login - Login user
// ============================================================
router.post("/login", async (req, res) => {
  try {
    const db = getDb();
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        msg: "Email dan password harus diisi!",
      });
    }

    // Cari user berdasarkan email
    const result = db.exec(
      `SELECT * FROM danru WHERE email = ?`,
      [email]
    );

    if (!result.length || !result[0].values.length) {
      return res.status(401).json({
        msg: "Email atau password salah!",
      });
    }

    // Mapping hasil query ke object
    const columns = result[0].columns;
    const row = result[0].values[0];
    const user = {};
    columns.forEach((col, idx) => {
      user[col] = row[idx];
    });

    // Verifikasi password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({
        msg: "Email atau password salah!",
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      {
        email: user.email,
        userId: user.id_danru,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: process.env.JWT_EXPIRES_IN || "7d",
      }
    );

    // Update last_login
    db.run(
      `UPDATE danru SET last_login = datetime('now') WHERE id_danru = ?`,
      [user.id_danru]
    );
    saveDatabase();

    // Kirim response TANPA password hash
    return res.status(200).json({
      msg: "Login berhasil!",
      token,
      user: {
        id_danru: user.id_danru,
        email: user.email,
        name: user.name,
        last_login: user.last_login,
      },
    });
  } catch (err) {
    console.error("Error login:", err);
    return res.status(500).json({
      msg: "Terjadi kesalahan saat login",
      error: err.message,
    });
  }
});

// ============================================================
// GET /secret-route - Protected route (butuh token)
// ============================================================
router.get("/secret-route", userMiddleware.isLoggedIn, (req, res) => {
  res.json({
    msg: "Selamat! Anda berhasil mengakses konten rahasia.",
    user: req.userData,
  });
});

// ============================================================
// GET /health - Health check endpoint
// ============================================================
router.get("/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
