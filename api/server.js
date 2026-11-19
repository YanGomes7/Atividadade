const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const app = express();
const PORT = process.env.PORT || 3000;

// CORS: permite a origem da aplicação web (VM1) e os métodos GET, POST e OPTIONS
const origin = process.env.CORS_ORIGIN || '*';
const corsOptions = {
  origin: origin === '*' ? true : origin.split(',').map((o) => o.trim()),
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type'],
};
app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json());

let pool;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function initDb() {
  for (let i = 1; i <= 60; i++) {
    try {
      pool = mysql.createPool({
        host: process.env.DB_HOST || 'db',
        user: process.env.DB_USER || 'app',
        password: process.env.DB_PASSWORD || 'apppass',
        database: process.env.DB_NAME || 'loja',
        waitForConnections: true,
        connectionLimit: 10,
      });
      await pool.query(`CREATE TABLE IF NOT EXISTS produtos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nome VARCHAR(255) NOT NULL,
        categoria VARCHAR(255) NOT NULL,
        preco DECIMAL(10,2) NOT NULL,
        quantidade INT NOT NULL
      )`);
      console.log('MySQL conectado');
      return;
    } catch (e) {
      console.log(`Aguardando MySQL (${i}/60): ${e.message}`);
      await sleep(2000);
    }
  }
  throw new Error('Não foi possível conectar ao MySQL');
}

app.post('/produto', async (req, res) => {
  const { nome, categoria, preco, quantidade } = req.body || {};
  const p = Number(preco);
  const q = Number(quantidade);
  if (!nome || !categoria || !Number.isFinite(p) || !Number.isInteger(q)) {
    return res.status(400).json({ erro: 'Campos inválidos: nome, categoria, preco (decimal), quantidade (inteiro)' });
  }
  try {
    const [r] = await pool.query(
      'INSERT INTO produtos (nome, categoria, preco, quantidade) VALUES (?, ?, ?, ?)',
      [nome, categoria, p, q]
    );
    res.status(201).json({ id: r.insertId, nome, categoria, preco: p, quantidade: q });
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: 'Erro ao gravar produto' });
  }
});

app.get('/produtos', async (_req, res) => {
  try {
    const [rows] = await pool.query('SELECT id, nome, categoria, preco, quantidade FROM produtos ORDER BY id');
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ erro: 'Erro ao consultar produtos' });
  }
});

initDb()
  .then(() => app.listen(PORT, '0.0.0.0', () => console.log(`API na porta ${PORT}`)))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
