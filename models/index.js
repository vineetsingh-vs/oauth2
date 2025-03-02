'use strict';

const fs = require('fs');
const path = require('path');
const Sequelize = require('sequelize');
const process = require('process');
const basename = path.basename(__filename);
const env = process.env.NODE_ENV;
const config = require(__dirname + '/../config/config.js')[env];
const db = {};

let sequelize;
if (config.use_env_variable) {
  sequelize = new Sequelize(process.env[config.use_env_variable], config);
} else {
  console.log("Menv", env);
  console.log("host", config.host);
  sequelize = new Sequelize(config.database, config.username, config.password, {
    host: "maddie-dev.cf8csamqy6sl.us-east-2.rds.amazonaws.com",
    dialect: config.dialect,
    logging: false,
    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: false // You might want to adjust this based on your security needs.
      }
    }
  });
}

fs
  .readdirSync(__dirname)
  .filter(file => {
    return (
      file.indexOf('.') !== 0 &&
      file !== basename &&
      file.slice(-3) === '.js' &&
      file.indexOf('.test.js') === -1
    );
  })
  .forEach(file => {
    const model = require(path.join(__dirname, file))(sequelize, Sequelize.DataTypes);
    db[model.name] = model;
  });

Object.keys(db).forEach(modelName => {
  if (db[modelName].associate) {
    db[modelName].associate(db);
  }
});


sequelize.sync()
  .then(() => {
    console.log("Models synced with database!");
  })
  .catch((err) => {
    console.error("Error syncing the model:", err);
  });


db.sequelize = sequelize;
db.Sequelize = Sequelize;


module.exports = db;
