// app.js

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const { initDatabase } = require("./config/database");

const app = express();
const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || "0.0.0.0";

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Routes
const router = require("./routes/router.js");
app.use("/", router);

// Global error handler
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({
    msg: "Internal server error",
    error: process.env.NODE_ENV === "development" ? err.message : undefined,
  });
});

// Initialize database lalu start server
initDatabase()
  .then(() => {
    app.listen(PORT, HOST, () => {
      console.log(`Server running at http://${HOST}:${PORT}`);
    });
  })
  .catch((err) => {
    console.error("Gagal inisialisasi database:", err);
    process.exit(1);
  });
