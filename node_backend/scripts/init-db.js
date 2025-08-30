const { Pool } = require('pg');
require('dotenv').config();

const { DATABASE_URL } = process.env;

if (!DATABASE_URL) {
  console.error('DATABASE_URL is not set in .env file');
  process.exit(1);
}

// Parse the database URL to get connection parameters
const dbUrl = new URL(DATABASE_URL);
const dbName = dbUrl.pathname.slice(1);

// Create a connection to the default 'postgres' database to create our database
const adminConfig = {
  user: dbUrl.username,
  password: dbUrl.password,
  host: dbUrl.hostname,
  port: dbUrl.port || 5432,
  database: 'postgres', // Connect to default database
  ssl: dbUrl.searchParams.get('sslmode') === 'require' ? { rejectUnauthorized: false } : false
};

async function createDatabase() {
  const pool = new Pool(adminConfig);
  const client = await pool.connect();
  
  try {
    // Check if database exists
    const dbExists = await client.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [dbName]
    );

    if (dbExists.rows.length === 0) {
      console.log(`Creating database: ${dbName}`);
      await client.query(`CREATE DATABASE ${dbName}`);
      console.log('Database created successfully');
    } else {
      console.log(`Database ${dbName} already exists`);
    }
  } catch (error) {
    console.error('Error creating database:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

createDatabase()
  .then(() => {
    console.log('Database setup completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Database setup failed:', error);
    process.exit(1);
  });
