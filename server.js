const express = require('express');
const cors = require('cors');
const mongodb = require('mongodb');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(express.json());

require('dotenv').config()

const url = process.env.MONGODB_URL
const client = new mongodb.MongoClient(url);

let db;
let users;

//#region == Utility Functions ==

function makeToken() {
  return crypto.randomBytes(32).toString('hex');
}

function makeExpiration(delay_days, delay_hours) {
  const d = new Date();
  d.setDate(d.getDate() + delay_days); // add delay as days from now
  d.setHours(d.getHours() + delay_hours); // add delay as hours from now
  return d;
}

async function isUserAuthd(req, res) {
  var token = req.header('token');
  var isAuthd = true;

  if(!token){
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
    else if (user.isVerified == false) {
      res.status(403).json({
        error: 'Email not verified'
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

async function sendEmail(to, subject, content) {
  try {
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: process.env.SMTP_PORT,
      secure: false,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      },
      tls: {
        ciphers: "TLSv1.2"
      }
    });

    await transporter.sendMail({
      from: process.env.SMTP_NO_REPLY,
      to: to,
      subject: subject,
      html: content

    })

  }
  catch (error) {
    console.error("Error sending email:", error)
  }
}

async function sendVerificationEmail(user){
  const emailVerificationToken = makeToken();

  // save verification details
  await users.updateOne(
      { _id: user._id },
      { $set: 
        {
          emailVerificationToken: emailVerificationToken
        }
       }
    );

  var cerifyUrl = `${process.env.APP_BASE_URL}/api/user/verify-email?token=${emailVerificationToken}`;

  var content = "Welcome to Collector’s Pair-A-Dice! Please verify your email with this link: " + cerifyUrl

  await sendEmail(user.email, "Please Verify Your Email", content)
}

function hashPassword(password) {
  return crypto.createHash('md5').update(password).digest('hex');
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
  try {
    var category = await categories.findOne({ _id: new mongodb.ObjectId(categoryId) }); 
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid category ID'
    })
  }

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
  try {
    var category = await categories.findOne({ _id: new mongodb.ObjectId(categoryId) }); 
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid category ID'
    })
  }

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

// get items in category
app.get('/api/categories/items', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  try {
    var categoryId = req.query.categoryId;
  } catch (err) {
    return res.status(400).json({
      error: 'Missing required fields.'
    })
  }

  // find specified category
  try {
    var category = await categories.findOne({_id: new mongodb.ObjectId(categoryId)});
  }
  catch (err) {
    return res.status(400).json({
      error: 'Invalid category ID'
    })
  }
  
  // check if category is null & user has permission to edit it
  if (!category || !category.userId.equals(user._id)) {
    return res.status(400).json({
      success: false,
      error: 'Category not found, or lacking permissions.'
    })
  }

  // get items related to category
  try {
    var userItems = await items.find({categoryId: category._id}, {projection: {userId: 0}}).toArray();

    return res.status(200).json({
      categoryId: categoryId,
      items: userItems,
      error: ""
    })

  } catch (err) {
    return res.status(500).json({
      items: [],
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

  if (!collectionName || !categoryId) {
    return res.status(400).json({
      error: 'Missing required fields.'
    });
  }

  try {
    var category = await categories.findOne({
      _id: new mongodb.ObjectId(categoryId)
    });

    if (!category || !category.userId.equals(user._id)) {
      return res.status(400).json({
        error: 'Category not found, or lacking permissions.'
      });
    }

    var newCollection = {
      userId: user._id,
      categoryId: category._id,
      collectionName: collectionName
    };

    var result = await collections.insertOne(newCollection);

    return res.status(200).json({
      id: result.insertedId.toString(),
      collectionName: collectionName,
      categoryId: category._id.toString(),
      error: ''
    });
  } catch (err) {
    return res.status(400).json({
      id: '',
      collectionName: '',
      categoryId: '',
      error: 'Invalid category ID'
    });
  }
});

// remove collections
app.delete('/api/collections', async (req, res) => {
  var[res, isAuthd, user] = await isUserAuthd(req, res);
  if(!isAuthd){
    return res;
  }

  var { collectionId } = req.body;

  if(!collectionId) {
    return res.status(400).json({
      error: 'Missing required fields'
    });
  }

  try {
    var collection = await collections.findOne({ _id: new mongodb.ObjectId(collectionId) });

    if (!collection || !collection.userId.equals(user._id)) {
      return res.status(400).json({
        success: false,
        error: 'Collection not found, or lacking permissions.'
      });
    }

    await collectionItems.deleteMany({ collectionId: collection._id });
    await collections.deleteOne({ _id: collection._id });

    return res.status(200).json({
      succes: true,
      error: ''
    });
  } catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid collection ID'
    });
  }
})

// update collections
app.patch('/api/collections', async (req, res) => {
  var[res, isAuthd, user] = await isUserAuthd(req, res);
  if(!isAuthd) {
    return res;
  }

  var { collectionId, collectionName, categoryId } = req.body;

  if(!collectionId || (!collectionName && !categoryId)) {
    return res.status(400).json({
      error: 'Missing required fields'
    });
  }

  try {
    var collection = await collections.findOne({ _id: new mongodb.ObjectId(collectionId) });

    if(!collection || !collection.userId.equals(user._id)) {
      return res.status(400).json({
        success: false,
        error: 'Collection not found, or lacking permissions.'
      });
    }

    var toUpdate = {};

    if(collectionName) {
      toUpdate.collectionName = collectionName;
    }

    if(categoryId) {
      var category = await categories.findOne({ _id: new mongodb.ObjectId(categoryId) });
      
      if(!category || !category.userId.equals(user._id)) {
        return res.status(400).json({
          success: false,
          error: 'Category not found, or lacking permissions.'
        });
      }
      
      toUpdate.categoryId = category._id;
    }

    await collections.updateOne(
      { _id: collection._id },
      { $set: toUpdate }
    );

    return res.status(200).json({
      success: true,
      error: ''
    });
  } catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid collection ID or category ID'
    });
  }
});

// get existing collections
app.get('/api/collections', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  try {
    var foundCollections = await collections.find({ userId: user._id }).toArray();

    return res.status(200).json({
      collections: foundCollections,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      collections: [],
      error: err.toString()
    });
  }
});

//#endregion

//#region == CRUD Operations for Items ==

// get existing item
app.get('/api/items', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  try {
  var itemId = req.query.itemId;
  } catch (err) {
    return req.status(400).json({
      error: 'Missing required fields.'
    })
  }

  // find specified item
  try {
    var item = await items.findOne({userId: user._id, _id: new mongodb.ObjectId(itemId)}, {projection: {userId: 0}});
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid item ID'
    })
  }

  // check if category is null & user has permission to edit it
  if (!item) {
    return res.status(400).json({
      item: {},
      error: 'Item not found, or lacking permissions.'
    })
  }

  return res.status(200).json({
    item: item,
    error: ''
  })
})

// update items
app.patch('/api/items', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { itemId, itemName, categoryId } = req.body;

  if (!itemId || (!itemName && !categoryId)) {
    return res.status(400).json({
      error: 'Missing required fields'
    })
  }

  let toUpdate = {};

  if (itemName) {toUpdate["itemName"] = itemName}
  if (categoryId) {
    try {
    toUpdate["categoryId"] = new mongodb.ObjectId(categoryId)
    } catch (err) {
      return res.status(400).json({
        success: false, 
        error: "Invalid category ID"
      });
    }
  }

  // get item
  try {
    var item = await items.findOne({ _id: new mongodb.ObjectId(itemId) }); 
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid item ID'
    })
  }

  // check if category is null & user has permission to edit it
  if (!item || !item.userId.equals(user._id)) {
    return res.status(400).json({
      success: false,
      error: 'Item not found, or lacking permissions.'
    })
  }

  // update category
  try {
    await items.updateOne(
      { _id: item._id },
      {
        $set: toUpdate
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

// add items
app.post('/api/items', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { itemName, categoryId } = req.body;

  if (!itemName || !categoryId) {
    return res.status(400).json({
      error: 'Missing required fields.'
    });
  }
  
  try {
    var newItem = {
      userId: user._id,
      categoryId: new mongodb.ObjectId(categoryId),
      itemName: itemName
    };
  } catch (err) {
    return res.status(400).json({
      itemName: "",
      categoryId: "",
      error: "Invalid category ID"
    })
  }
  try {
    var result = await items.insertOne(newItem);

    return res.status(200).json({
      _id: result.insertedId.toString(),
      itemName: itemName,
      categoryId: categoryId,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      _id: '',
      itemName: '',
      categoryId: '',
      error: err.toString()
    });
  }
})

// remove items
app.delete('/api/items', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { itemId } = req.body;

  if (!itemId) {
    return res.status(400).json({
      error: 'Missing required fields'
    })
  }

  // get category
  try {
    var item = await items.findOne({ _id: new mongodb.ObjectId(itemId) }); 

    if(!item || !item.userId.equals(user._id)){
      return res.status(400).json({
        success: false,
        error: 'Item not found, or lacking permissions'
      });
    }

    await collectionItems.deleteMany({ itemId: item._id });
    await itemCriteria.deleteMany({ itemId: item._id });
    await items.deleteOne({ _id: item._id });

    return res.status(200).json({
      success: true,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: 'Invalid item ID'
    });
  }
});

//#endregion

//#region == Search API ==

app.post('/api/search/items', async (req, res) => {
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { category, categoryId, criteria, generalSearch } = req.body;

  // allow either "category" or "categoryId"
  var finalCategoryId = categoryId || category;

  if (!finalCategoryId) {
    return res.status(400).json({
      items: [],
      error: 'Missing category ID'
    });
  }

  if (!criteria) {
    criteria = {};
  }

  if (typeof criteria !== 'object' || Array.isArray(criteria)) {
    return res.status(400).json({
      items: [],
      error: 'criteria must be an object'
    });
  }

  try {
    // 1) validate category and ownership
    var foundCategory = await categories.findOne({
      _id: new mongodb.ObjectId(finalCategoryId)
    });

    if (!foundCategory || !foundCategory.userId.equals(user._id)) {
      return res.status(400).json({
        items: [],
        error: 'Category not found, or lacking permissions.'
      });
    }

    // 2) start with all item IDs in this category owned by this user
    var categoryItems = await items.find({
      userId: user._id,
      categoryId: foundCategory._id
    }).toArray();

    var allowedItemIds = categoryItems.map(item => item._id);

    // if category has no items, stop early
    if (allowedItemIds.length === 0) {
      return res.status(200).json({
        items: [],
        error: ''
      });
    }

    // helper to compare ObjectIds using strings
    function intersectObjectIdArrays(arr1, arr2) {
      var set2 = new Set(arr2.map(x => x.toString()));
      return arr1.filter(x => set2.has(x.toString()));
    }

    // 3) apply each specific criteria filter as an AND filter
    for (const [criteriaId, criteriaSearchValue] of Object.entries(criteria)) {
      if (
        criteriaSearchValue === null ||
        criteriaSearchValue === undefined ||
        criteriaSearchValue === ''
      ) {
        continue;
      }

      var foundCategoryCriteria = await categoryCriteria.findOne({
        _id: new mongodb.ObjectId(criteriaId)
      });

      if (!foundCategoryCriteria) {
        return res.status(400).json({
          items: [],
          error: `Invalid category criteria ID: ${criteriaId}`
        });
      }

      // make sure this criteria belongs to the chosen category
      if (!foundCategoryCriteria.categoryId.equals(foundCategory._id)) {
        return res.status(400).json({
          items: [],
          error: `Criteria ${criteriaId} does not belong to the selected category`
        });
      }

      var regex = new RegExp(criteriaSearchValue, 'i');

      var matchingItemCriteria = await itemCriteria.find({
        categoryCriteriaId: foundCategoryCriteria._id,
        criteriaValue: { $regex: regex },
        itemId: { $in: allowedItemIds }
      }).toArray();

      var matchedItemIdsForThisCriteria = matchingItemCriteria.map(x => x.itemId);

      allowedItemIds = intersectObjectIdArrays(allowedItemIds, matchedItemIdsForThisCriteria);

      if (allowedItemIds.length === 0) {
        return res.status(200).json({
          items: [],
          error: ''
        });
      }
    }

    // 4) apply generalSearch, if present
    if (generalSearch && generalSearch.trim() !== '') {
      var generalRegex = new RegExp(generalSearch, 'i');

      // item name matches
      var itemNameMatches = await items.find({
        _id: { $in: allowedItemIds },
        userId: user._id,
        categoryId: foundCategory._id,
        itemName: { $regex: generalRegex }
      }).toArray();

      var itemNameMatchIds = itemNameMatches.map(x => x._id);

      // criteria value matches
      var criteriaMatches = await itemCriteria.find({
        itemId: { $in: allowedItemIds },
        criteriaValue: { $regex: generalRegex }
      }).toArray();

      var criteriaMatchIds = criteriaMatches.map(x => x.itemId);

      // union of generalSearch matches
      var generalMatchIdMap = new Map();

      for (var id of itemNameMatchIds) {
        generalMatchIdMap.set(id.toString(), id);
      }

      for (var id of criteriaMatchIds) {
        generalMatchIdMap.set(id.toString(), id);
      }

      var generalMatchedIds = Array.from(generalMatchIdMap.values());

      allowedItemIds = intersectObjectIdArrays(allowedItemIds, generalMatchedIds);

      if (allowedItemIds.length === 0) {
        return res.status(200).json({
          items: [],
          error: ''
        });
      }
    }

    // 5) fetch final matching items
    var finalItems = await items.find({
      _id: { $in: allowedItemIds },
      userId: user._id,
      categoryId: foundCategory._id
    }).toArray();

    return res.status(200).json({
      items: finalItems,
      error: ''
    });

  } catch (err) {
    return res.status(500).json({
      items: [],
      error: err.toString()
    });
  }
});

//#endregion

//#region == CRUD Operations for Category Criteria ==

// get existing tags
app.get('/api/categories/criteria', async (req, res) => {
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { categoryId } = req.query;

  if (!categoryId) {
    return res.status(400).json({
      criteria: [],
      error: 'Missing required fields.'
    });
  }

  try {
    var category = await categories.findOne({
      _id: new mongodb.ObjectId(categoryId)
    });

    if (!category || !category.userId.equals(user._id)) {
      return res.status(400).json({
        criteria: [],
        error: 'Category not found, or lacking permissions.'
      });
    }

    var criteria = await categoryCriteria.find({
      categoryId: category._id
    }).toArray();

    return res.status(200).json({
      criteria: criteria,
      error: ''
    });
  } catch (err) {
    return res.status(400).json({
      criteria: [],
      error: 'Invalid category ID'
    });
  }
});

// add category criteria
app.post('/api/categories/criteria', async (req, res) => {
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { criteriaName, categoryId } = req.body;

  if (!criteriaName || !categoryId) {
    return res.status(400).json({
      error: 'Missing required fields.'
    });
  }

  try {
    var category = await categories.findOne({
      _id: new mongodb.ObjectId(categoryId)
    });

    if (!category || !category.userId.equals(user._id)) {
      return res.status(400).json({
        error: 'Category not found, or lacking permissions.'
      });
    }

    var newCriteria = {
      userId: user._id,
      categoryId: category._id,
      criteriaName: criteriaName
    };

    var result = await categoryCriteria.insertOne(newCriteria);

    return res.status(200).json({
      _id: result.insertedId.toString(),
      criteriaName: criteriaName,
      categoryId: categoryId,
      error: ''
    });
  } catch (err) {
    return res.status(400).json({
      _id: '',
      criteriaName: '',
      categoryId: '',
      error: 'Invalid category ID'
    });
  }
});

// delete category criteria
app.delete('/api/categories/criteria', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { criteriaId } = req.body;

  if (!criteriaId) {
    return res.status(400).json({
      error: 'Missing required fields'
    })
  }

  console.log("found criteria id")

  // get criteria
  try {
    var criteria = await categoryCriteria.findOne({ _id: new mongodb.ObjectId(criteriaId) }); 
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid category criteria ID'
    })
  }

  // check if category is null & user has permission to remove it
  if (!criteria || !criteria.userId.equals(user._id)) {
    return res.status(400).json({
      success: false,
      error: 'Category criteria not found, or lacking permissions'
    })
  }

  try {
    await itemCriteria.deleteMany({ categoryCriteriaId: criteria._id })
    await categoryCriteria.deleteOne({ _id: criteria._id });

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

app.patch('/api/categories/criteria', async (req, res) => {
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { criteriaId, criteriaName } = req.body;

  if (!criteriaId || !criteriaName) {
    return res.status(400).json({
      error: 'Missing required fields'
    });
  }

  try {
    var criteria = await categoryCriteria.findOne({
      _id: new mongodb.ObjectId(criteriaId)
    });

    if (!criteria || !criteria.userId.equals(user._id)) {
      return res.status(400).json({
        success: false,
        error: 'Category criteria not found, or lacking permissions.'
      });
    }

    await categoryCriteria.updateOne(
      { _id: criteria._id },
      {
        $set: {
          criteriaName: criteriaName
        }
      }
    );

    return res.status(200).json({
      success: true,
      error: ''
    });
  } catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid category criteria ID'
    });
  }
});

//#endregion

//#region == CRUD Operations for Item criteria

// get item criteria
app.get('/api/items/criteria', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  try {
  var itemCriteriaId = req.query.itemCriteriaId;
  } catch (err) {
    return req.status(400).json({
      error: 'Missing required fields.'
    })
  }

  // find specified criteria
  try {
    var criteria = await itemCriteria.findOne({userId: user._id, _id: new mongodb.ObjectId(itemCriteriaId)}, {projection: {userId: 0}});
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid item criteria ID'
    })
  }

  // check if criteria is null & user has permission to edit it
  if (!criteria) {
    return res.status(400).json({
      criteria: {},
      error: 'Item criteria not found, or lacking permissions.'
    })
  }

  return res.status(200).json({
    itemCriteria: criteria,
    error: ''
  })
});

// add new item criteria
app.post('/api/items/criteria', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { itemId, criteriaId, value } = req.body;

  if (!itemId || !criteriaId || !value) {
    return res.status(400).json({
      error: 'Missing required fields'
    });
  }
  
  // ensure item exists
  try {
    var item = await items.findOne({userId: user._id, _id: new mongodb.ObjectId(itemId)}, {projection: {userId: 0}});
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid item ID'
    })
  }

  // ensure criteria exists
  try {
    var criteria = await categoryCriteria.findOne({userId: user._id, _id: new mongodb.ObjectId(criteriaId)}, {projection: {userId: 0}});
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid criteria ID'
    })
  }  

  if (!item || !criteria) {
    return res.status(400).json({
      success: false,
      error: 'Item or Criteria not found or missing permission'
    })
  }

  // ensure item is in the same category as the criteria
  if (item.categoryId.toString() != criteria.categoryId.toString()) {
    return res.status(400).json({
      success: false,
      error: 'Item does not match criteria category'
    })
  }

  try {
    var newItemCriteria = {
    userId: user._id,
    itemId: new mongodb.ObjectId(itemId),
    categoryCriteriaId: new mongodb.ObjectId(criteriaId),
    criteriaValue: value
  };
  } catch (err) {
    return res.status(400).json({
      itemCriteria: "",
      itemId: "",
      criteriaId: "",
      error: "Invalid category ID"
    })
  }
  try {
    var result = await itemCriteria.insertOne(newItemCriteria);

    return res.status(200).json({
      _id: result.insertedId.toString(),
      value: value,
      itemId: itemId,
      categoryCriteriaId: criteriaId,
      error: ''
    });
  } catch (err) {
    return res.status(500).json({
      error: err.toString()
    });
  }
});

// delete item criteria
app.delete('/api/items/criteria', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { criteriaId } = req.body;

  if (!criteriaId) {
    return res.status(400).json({
      error: 'Missing required fields'
    })
  }

  // get criteria
  try {
    var criteria = await itemCriteria.findOne({ _id: new mongodb.ObjectId(criteriaId) }); 
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid category criteria ID'
    })
  }

  // check if category is null & user has permission to remove it
  if (!criteria || !criteria.userId.equals(user._id)) {
    return res.status(400).json({
      success: false,
      error: 'Item criteria not found, or lacking permissions'
    })
  }

  try {
    await itemCriteria.deleteOne({ _id: criteria._id });

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
});

// update item criteria
app.patch('/api/items/criteria', async (req, res) => {
  // ensure user is authenticated
  var [res, isAuthd, user] = await isUserAuthd(req, res);
  if (!isAuthd) {
    return res;
  }

  var { criteriaId, value } = req.body;

  if (!criteriaId || !value) {
    return res.status(400).json({
      error: 'Missing required fields'
    })
  }

  // get item
  try {
    var criteria = await itemCriteria.findOne({ _id: new mongodb.ObjectId(criteriaId) }); 
  }
  catch (err) {
    return res.status(400).json({
      success: false,
      error: 'Invalid category criteria ID'
    })
  }

  // check if category is null & user has permission to edit it
  if (!criteria || !criteria.userId.equals(user._id)) {
    return res.status(400).json({
      success: false,
      error: 'Category criteria not found, or lacking permissions.'
    })
  }

  // update category
  try {
    await itemCriteria.updateOne(
      { _id: criteria._id },
      {
        $set: {
          criteriaValue: value
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
});


//#endregion

//#region == User Operations ==

app.post('/api/user/register', async (req, res) => {
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

    const newUser = {
      email,
      password: hashPassword(password),
      isVerified: false,
      emailVerificationToken: null,
      sessionToken: null,
      sessionExpiration: null,
      passwordResetToken: null,
      passwordResetExpiration: null
    };

    const result = await users.insertOne(newUser);

    const createdUser = await users.findOne({ _id: result.insertedId });
    await sendVerificationEmail(createdUser);

    return res.status(200).json({
      id: result.insertedId.toString(),
      email,
      sessionToken: '',
      sessionExpiration: '',
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

app.post('/api/user/login', async (req, res) => {
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
    const hashedPassword = hashPassword(password)

    const user = await users.findOne({ email: email, password: hashedPassword });

    if (!user) {
      return res.status(401).json({
        id: '',
        email: '',
        sessionToken: '',
        sessionExpiration: '',
        error: 'Invalid email/password'
      });
    }

    if(!user.isVerified) {
      return res.status(403).json({
        id: '',
        email: '',
        sessionToken: '',
        sessionExpiration: '',
        error: 'Please verify your email before logging in'
      });
    }

    let sessionToken = user.sessionToken;
    let sessionExpiration = user.sessionExpiration;

    const currentTime = new Date();

    if (!sessionToken || !sessionExpiration || currentTime >= sessionExpiration) {
      sessionToken = makeToken();
      sessionExpiration = makeExpiration(7, 0);

      await users.updateOne(
        { _id: user._id },
        {
          $set: {
            sessionToken: sessionToken,
            sessionExpiration: sessionExpiration
          }
        }
      );
    }

    return res.status(200).json({
      id: user._id.toString(),
      email: user.email,
      sessionToken: sessionToken,
      sessionExpiration: sessionExpiration,
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

app.get('/api/user/verify-email', async(req, res) =>{
  const { token } = req.query;

  if(!token) {
    return res.status(400).send('Missing verification token');
  }

  try {
    const user = await users.findOne({ emailVerificationToken: token });
    
    if(!user) {
      return res.status(400).send('Invalid verification token');
    }

    await users.updateOne(
      { _id: user._id },
      {
        $set : {
          isVerified: true,
          emailVerificationToken: "",
        }
      }
    );

    return res.status(200).send('Email verified successfully. You can now log in.');
  } catch (err) {
    return res.status(500).send('Server error while verifying email');
  }
});

// request password reset
app.get('/api/user/request-password-reset', async (req, res) => {
  var { email } = req.query;

  // attempt to find user account with email
  var user = await users.findOne( { email: email });

  // if user found, send password reset
  if (user && user.isVerified) {
    // generate new password token & expiration
    var passwordResetToken = makeToken()
    var passwordResetExpiration = makeExpiration(0, 1)

    // update user
    await users.updateOne(
      {_id: user._id},
      {
        $set : {
          passwordResetToken: passwordResetToken,
          passwordResetExpiration: passwordResetExpiration
        }
      }
    )

    var resetUrl = `${process.env.APP_BASE_URL}/api/user/reset-password?token=${passwordResetToken}`;

    var content = '<p>Please use this link to reset your password: <a href="' + resetUrl + '">reset</a><br><i>The link will expire in 1 hour.</i></p>'

    sendEmail(email, "Password Reset", content)
  }
  
  return res.status(200).send("Password reset sent.")

})

// password reset
app.put('/api/user/reset-password', async (req, res) => {
  var { token, newPassword } = req.body;

  if (!token || !newPassword) {
    return res.status(400).json({
      error: 'Missing required data'
    })
  }

  // find user with password reset token
  var user = await users.findOne({passwordResetToken: token})

  if (!user) {
    return res.status(400).json({
      error: 'Invalid password reset token'
    })
  }

  var currentTime = new Date();
  // ensure token is still valid, replace if not
  if (currentTime >= user.passwordResetExpiration) {
    return res.status(400).json({
      error: 'Password reset token expired'
    })
  }

  // update password
  await users.updateOne(
    { _id: user._id },
    {
      $set: {
        sessionToken: null,
        sessionExpiration: null,
        passwordResetToken: null,
        passwordResetExpiration: null,
        password: hashPassword(newPassword)
      }
    }
  )

  return res.status(200).json({error: ''})

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
  collectionItems = db.collection('collection_items');
  categoryCriteria = db.collection('category_criteria');
  itemCriteria = db.collection('item_criteria');

  app.listen(5000, () => {
    console.log('Server running on port 5000');
  });
}

startServer().catch(err => {
  console.error('Failed to start server:', err);
});

//#endregion