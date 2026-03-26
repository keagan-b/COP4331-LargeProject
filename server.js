const express = require('express');
const cors = require('cors');
const mongodb = require('mongodb');
const crypto = require('crypto');

const app = express();
app.use(cors());
app.use(express.json());

require('dotenv').config()

const url = process.env.MONGODB_URL
const client = new mongodb.MongoClient(url);

let db;
let users;

//#region == Utility Functions ==

function makeSessionToken() {
  return crypto.randomBytes(32).toString('hex');
}

function makeSessionExpiration() {
  const d = new Date();
  d.setDate(d.getDate() + 7); // 7 days from now
  return d;
}

async function isUserAuthd(req, res) {
  var { token } = req.body;
  var isAuthd = true;

  // ensure body has correct info
  if (!token) {
    res.status(400).json({
      error: 'Missing token'
    });
    isAuthd = false;
  }

  if (isAuthd) {
    var user = await getUserFromToken(token);
    if (user == false) {
      res.status(403).json({
        error: 'Token expired'
      });
      isAuthd = false;
    }
    else if (user == null) {
      res.status(403).json({
        error: 'Invalid token'
      });
      isAuthd = false;
    }
  }

  return [res, isAuthd, user];
}

async function getUserFromToken(token) {
  // fetch a User object from a supplied token
  var user = await users.findOne({ sessionToken: token });

  // check that a user was found
  if (user != null) {
    var currentTime = new Date();
    // ensure token is still valid
    if (currentTime >= user.sessionExpiration)
    {
      // expired token, do not return a user, return 'false'
      user = false;
    }
  }

  return user;
}

//#endregion

//#region == CRUD Operations for Categories ==

// get existing categories
app.get('/api/categories', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  // find all categories belonging to this user
  var userCategories = await categories.find( {userId: user._id}, {projection: {userId: 0}} ).toArray()

  return res.status(200).json({
    userCategories: userCategories
  })

})

// update categories
app.patch('/api/categories', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { categoryId, categoryName } = req.body;

  if (!categoryId || !categoryName) {
    return res.status(400).json({
      error: 'Missing required fields'
    })
  }

  // get category
  var category = await categories.findOne({ _id: new mongodb.ObjectId(categoryId) }); 

  // check if category is null & user has permission to edit it
  if (!category || !category.userId.equals(user._id)) {
    return res.status(400).json({
      success: false,
      error: 'Category not found, or lacking permissions.'
    })
  }

  // update category
  try {
    await categories.updateOne(
      { _id: category._id },
      {
        $set: {
          categoryName: categoryName
        }
      }
    );

    return res.status(200).json({
      success: true,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: err.toString()
    });
  }

})

// add categories
app.post('/api/categories', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { categoryName } = req.body;

  if (!categoryName) {
    return res.status(400).json({
      error: 'Missing required fields.'
    })
  }

  try {
    var newCategory = {
      userId: user._id,
      categoryName: categoryName
    };

    var result = await categories.insertOne(newCategory);

    return res.status(200).json({
      _id: result.insertedId.toString(),
      categoryName: categoryName
    });
  } catch (err) {
    return res.status(500).json({
      _id: '',
      categoryName: '',
      error: err.toString()
    });
  }


})

// remove categories
app.delete('/api/categories', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { categoryId } = req.body;

  if (!categoryId) {
    return res.status(400).json({
      error: 'Missing required fields'
    })
  }

  // get category
  var category = await categories.findOne({ _id: new mongodb.ObjectId(categoryId) }); 

  // check if category is null & user has permission to remove it
  if (!category || !category.userId.equals(user._id)) {
    return res.status(400).json({
      success: false,
      error: 'Category not found, or lacking permissions.'
    })
  }

  try {
    await categories.deleteOne({ _id: category._id });

    return res.status(200).json({
      success: true,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: err.toString()
    });
  }

})

//#endregion

//#region == CRUD Operations for Collections ==

// add collections
app.post('/api/collections', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { categoryId, collectionName } = req.body;

  if (!collectionName) {
    return req.status(400).json({
      error: 'Missing required fields.'
    });
  }

  try {
    var newCollection = {
      userId: user._id,
      categoryId: categoryId,
      collectionName: collectionName
    };

    var result = await collections.insertOne(newCollection);

    return res.status(200).json({
      id: result.insertedId.toString(),
      collectionName: collectionName
    });
  } catch (err) {
    return res.status(500).json({
      id: '',
      collectionName: '',
      error: err.toString()
    });
  }

})

// remove collections
app.delete('/api/collections', async (req, res) => {

})

// update collections
app.patch('/api/collections', async (req, res) => {

})

// get existing collections
app.get('/api/collections', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }
  
  // find collections matching user data
  const collections = await collections.find({ userId: user._id })

  // no collections found, return empty array
  if (!collections) {
    collections = []
  }

  // return found collections
  return res.status(200).json({
    collections: collections,
    error: ''
  })

})

//#endregion

//#region == CRUD Operations for Items ==


// get existing items
app.get('/api/items', async (req, res) => {

})

// update items
app.patch('/api/items', async (req, res) => {

})

// add/remove items
app.post('/api/items', async (req, res) => {

})

// remove items
app.delete('/api/items', async (req, res) => {

})

//#endregion

//#region == CRUD Operations for Tags ==

// get existing tags
app.get('/api/tags', async (req, res) => {

})

// update tags
app.put('/api/tags', async (req, res) => {

})

// add/remove tags
app.post('/api/tags', async (req, res) => {

})

//#endregion

//#region == User Operations ==

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

// request password reset
app.post('/api/user/reset', async (req, res) => {

})

// password reset
app.put('/api/user/reset', async (req, res) => {

})

//#endregion

//#region == Server Start Command & Function ==

async function startServer() {
  await client.connect();
  db = client.db('collections_db');
  users = db.collection('users');
  collections = db.collection('collections');
  categories = db.collection('categories');
  items = db.collection('items');

  app.listen(5000, () => {
    console.log('Server running on port 5000');
  });
}

startServer().catch(err => {
  console.error('Failed to start server:', err);
});

//#endregion