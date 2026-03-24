const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');
const crypto = require('crypto');

const app = express();
app.use(cors());
app.use(express.json());

const url = 'mongodb+srv://Jamothey:12062000@largeproject.2mmcszw.mongodb.net/?appName=LargeProject';
const client = new MongoClient(url);

let db;
let users;

function makeSessionToken() {
  return crypto.randomBytes(32).toString('hex');
}

function makeSessionExpiration() {
  const d = new Date();
  d.setDate(d.getDate() + 7); // 7 days from now
  return d;
}

async function startServer() {
  await client.connect();
  db = client.db('collections_db');
  users = db.collection('users');

  app.listen(5000, () => {
    console.log('Server running on port 5000');
  });
}

app.post('/api/register', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      id: '',
      email: '',
      sessionToken: '',
      sessionExpiration: '',
      error: 'Missing required fields'
    });
  }

  try {
    const existingUser = await users.findOne({ email: email });

    if (existingUser) {
      return res.status(409).json({
        id: '',
        email: '',
        sessionToken: '',
        sessionExpiration: '',
        error: 'Email already exists'
      });
    }

    const sessionToken = makeSessionToken();
    const sessionExpiration = makeSessionExpiration();

    const newUser = {
      email,
      password,
      sessionToken,
      sessionExpiration,
      passwordResetToken: null,
      passwordResetExpiration: null
    };

    const result = await users.insertOne(newUser);

    return res.status(200).json({
      id: result.insertedId.toString(),
      email,
      sessionToken,
      sessionExpiration,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      id: '',
      email: '',
      sessionToken: '',
      sessionExpiration: '',
      error: err.toString()
    });
  }
});

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      id: '',
      email: '',
      sessionToken: '',
      sessionExpiration: '',
      error: 'Missing email or password'
    });
  }

  try {
    const user = await users.findOne({ email: email, password: password });

    if (!user) {
      return res.status(401).json({
        id: '',
        email: '',
        sessionToken: '',
        sessionExpiration: '',
        error: 'Invalid email/password'
      });
    }

    const sessionToken = makeSessionToken();
    const sessionExpiration = makeSessionExpiration();

    await users.updateOne(
      { _id: user._id },
      {
        $set: {
          sessionToken: sessionToken,
          sessionExpiration: sessionExpiration
        }
      }
    );

    return res.status(200).json({
      id: user._id.toString(),
      email: user.email,
      sessionToken,
      sessionExpiration,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      id: '',
      email: '',
      sessionToken: '',
      sessionExpiration: '',
      error: err.toString()
    });
  }
});


// get existing collections
app.get('/api/collections', async (req, res) => {

})

// update collections
app.put('/api/collections', async (req, res) => {

})

// add/remove collections
app.post('/api/collections', async (req, res) => {

})

// get existing items
app.get('/api/items', async (req, res) => {

})

// update items
app.put('/api/items', async (req, res) => {

})

// add/remove items
app.post('/api/items', async (req, res) => {

})

// get existing tags
app.get('/api/tags', async (req, res) => {

})

// update tags
app.put('/api/tags', async (req, res) => {

})

// add/remove tags
app.post('/api/tags', async (req, res) => {

})

// request password reset
app.post('/api/user/reset', async (req, res) => {

})

// password reset
app.put('/api/user/reset', async (req, res) => {

})

startServer().catch(err => {
  console.error('Failed to start server:', err);
});