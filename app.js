const express = require("express");
const bodyParser = require("body-parser");
const koneksi = require("./config/database");
const app = express();
const cors = require("cors");
const PORT = process.env.PORT || 5000;

//set body-parser
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

//create data || Insert data ()
/* app.post("/", (req, res) => {
  //buat variabel penampung data & query SQL
  const data = { ...req.body };
  const querySql = "INSERT into dbpn_anggota SET ?";

  //run Query
  koneksi.query(querySql, data, (err, rows, field) => {
    //error handling
    if (err) {
      return res
        .status(500)
        .json({ message: "Gagal memasukan data !", error: err });
    }
    //jika request berhasil
    res.status(201).json({ success: true, message: "Berhasil insert data!" });
  });
}); */
// add routes
const router = require("./routes/router.js");
app.use("/", router);
//untuk server nya
app.listen(PORT, "192.168.43.166", () =>
  console.log(`Server running at port: ${PORT}`)
);
