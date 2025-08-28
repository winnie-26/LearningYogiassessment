const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
const helmet = require('helmet');

const routes = require('./routes');

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

app.use('/healthz', (req, res) => res.status(200).json({ ok: true }));
app.use('/api/v1', routes);

// 404
app.use((req, res) => res.status(404).json({ error: 'not_found' }));

// Error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // eslint-disable-next-line no-console
  console.error('[error]', err);
  const status = err.status || 500;
  res.status(status).json({ error: err.code || 'internal_error', message: err.message });
});

module.exports = app;
