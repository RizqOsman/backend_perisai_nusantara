// middleware/users.js

const jwt = require("jsonwebtoken");

module.exports = {
  /**
   * Validasi data registrasi
   */
  validateRegister: (req, res, next) => {
    // email: harus ada dan format valid
    if (!req.body.email || req.body.email.length < 3) {
      return res.status(400).json({
        msg: "Masukkan email minimal 3 karakter",
      });
    }

    // Validasi format email sederhana
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(req.body.email)) {
      return res.status(400).json({
        msg: "Format email tidak valid",
      });
    }

    // nama: harus ada
    if (!req.body.name || req.body.name.trim().length < 2) {
      return res.status(400).json({
        msg: "Masukkan nama minimal 2 karakter",
      });
    }

    // password min 6 chars
    if (!req.body.password || req.body.password.length < 6) {
      return res.status(400).json({
        msg: "Masukkan password minimal 6 karakter",
      });
    }

    // password (repeat) harus sama
    if (
      !req.body.password_repeat ||
      req.body.password !== req.body.password_repeat
    ) {
      return res.status(400).json({
        msg: "Password dan konfirmasi password harus sama",
      });
    }

    next();
  },

  /**
   * Middleware: Verifikasi JWT token
   * Gunakan di route yang membutuhkan autentikasi
   */
  isLoggedIn: (req, res, next) => {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      return res.status(401).json({
        msg: "Akses ditolak! Token tidak ditemukan.",
      });
    }

    // Format: "Bearer <token>"
    const token = authHeader.split(" ")[1];

    if (!token) {
      return res.status(401).json({
        msg: "Format token tidak valid. Gunakan: Bearer <token>",
      });
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.userData = decoded;
      next();
    } catch (err) {
      return res.status(401).json({
        msg: "Token tidak valid atau sudah expired!",
      });
    }
  },
};
