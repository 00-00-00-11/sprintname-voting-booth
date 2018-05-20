'use strict';

require('ace-css/css/ace.css');
require('font-awesome/css/font-awesome.css');
require('./index.html'); // ensure index.html gets copied during build

const AuthWrapper = require('../dist/AuthWrapper.js');
const Database    = require('../dist/Database.js');
const VotingApp   = require('../dist/VotingApp.js');

/** **********************************************************************
 * main
 */

const auth = new AuthWrapper();
const credentials = auth.retrieveCredentials();

const votingApp = new VotingApp();
votingApp.run(credentials);
auth.register(votingApp.elmClient);

const database = new Database(votingApp.elmClient);

window.votingApp = votingApp;

