const mysql = require("mysql");

//konfigurasi koneksi
const koneksi = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "dbpn_anggota",
  multipleStatements: true,
});

//koneksi database
koneksi.connect((err) => {
  if (err) throw err;
  console.log("MySql Database Connected");
});
module.exports = koneksi;
