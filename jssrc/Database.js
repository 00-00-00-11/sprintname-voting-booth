'use strict';

const firebase = require('firebase/app');
require('firebase/auth');
require('firebase/database');

/** **********************************************************************
 * Database
 */

module.exports = (function (jQuery, firebase)
{
    /** **********************************************************************
     * Static data
     */
    const tokenserverUrl   = '/tokenserver';
    const firebaseTokenKey = 'elmVotingApp.firebaseToken';

    /** **********************************************************************
     * Constructor. This only installs the incoming port message listeners.
     */
    let Database = function (elmClient)
    {
        this.elmClient = elmClient;

        // ----- messages incoming from elm -----

        // application is ready for initialization of the database
        this.elmClient.ports.firebaseInit.subscribe(this.init.bind(this));

        // user clicked 'logout'
        this.elmClient.ports.firebaseLogout.subscribe(() => {
            firebase.auth().signOut();
        });

        // user logged in
        this.elmClient.ports.firebaseLoginWithJwtToken.subscribe(this.login.bind(this));

        // save user ratings to firebase
        this.elmClient.ports.saveUserRatings.subscribe(this.castVote.bind(this));

        // save page updates to firebase
        this.elmClient.ports.savePage.subscribe(this.savePage.bind(this));
    };

    /** **********************************************************************
     * instantiate and initialize the database
     */
    Database.prototype.init = function (firebaseConfig)
    {
        firebase.initializeApp(firebaseConfig);

        this.votingDb = {
            database: firebase.database(),
            settings: firebase.database().ref('settings'),
            pokedex : firebase.database().ref('pokedex'),
            pages   : firebase.database().ref('pages'),
            users   : firebase.database().ref('usersByEmail')
        };

        this.initListeners();
    };

    /** **********************************************************************
     * instantiate and initialize the outgoing port handlers.
     */
    Database.prototype.initListeners = function ()
    {
        // ----- messages outgoing to elm -----

        // when settings load
        this.votingDb.settings.on('value', (data) => {
            const settings = data.val();
            this.elmClient.ports.onLoadSettings.send(settings);
        });

        // when pokedex loads
        this.votingDb.pokedex.on('value', (data) => {
            const pokedex = data.val();
            this.elmClient.ports.onLoadPokedex.send(pokedex);
        });

        // when pages information loads (initially)
        this.votingDb.pages.once('value', (data) => {
            const pages = data.val();
            this.elmClient.ports.onLoadPages.send(pages);
        });

        // when pages information changes (when a page is closed)
        this.votingDb.pages.on('child_changed', (data) => {
            const page = data.val();
            this.elmClient.ports.onLoadPage.send(page);
        });

        // when user ratings load (initially: entire team)
        this.votingDb.users.once('value', (data) => {
            const team = Object.values(data.val());
            this.elmClient.ports.onLoadTeamRatings.send(team);
        });

        // when user ratings load (when a user votes)
        this.votingDb.users.on('child_changed', (data) => {
            const user = data.val();
            this.elmClient.ports.onLoadUserRatings.send(user);
        });

    }; // initListeners

    /** **********************************************************************
     * take a JWT token, obtain a firebase token, and log in in firebase
     */
    Database.prototype.login = function (jwtToken)
    {
        let me = this;

        jQuery
            .post({
                url: tokenserverUrl,
                data: { jwtToken }
            })
            .then(function (tokenData) {
                if (tokenData.success) {
                    return Promise.resolve(tokenData.firebaseToken);
                } else {
                    return Promise.reject(tokenData);
                }
            })
            .then(function (firebaseToken) {
                localStorage.setItem(firebaseTokenKey, firebaseToken);
                return firebase.auth().signInWithCustomToken(firebaseToken);
            })
            .catch(function (e) {
                let status = e.status;
                let message;
                if (e.responseJSON) {
                    message = e.responseJSON.message;
                } else if (e.message) {
                    message = e.message;
                } else if (!status) {
                    // A Status Code of 0 means "The browser refused to honor the request."
                    // @see https://salesforce.stackexchange.com/questions/158448/response-status-is-0-in-jquery-ajax
                    message = "The browser refused to honor the request (is the tokenserver reachable?)";
                } else {
                    message = String(status) + " Server error";
                }
                setTimeout(function () {
                    me.elmClient.ports.onFirebaseLoginFailed.send({ message, status });
                }, 100);
            });
        return;
    };

    /** **********************************************************************
     * database action: casting votes
     */
    Database.prototype.castVote = function (userRatings)
    {
        // id === null would correspond to a delete request.
        // id should not be null, but let's be defensive here.
        if (userRatings.id !== null) {
            let userRef = this.votingDb.users.child(
                // dots are not allowed in keys
                userRatings.email.replace(/\./g, '_')
            );
            // Database rules ensure that votes cannot be cast if the
            // application is in maintenance mode, so we don't check that here.
            userRef.set(userRatings);
        }
    };

    /** **********************************************************************
     * database action: save page
     */
    Database.prototype.savePage = function (page)
    {
        let pageRef = this.votingDb.pages.child(page.id);
        // Database rules ensure that votes cannot be cast if the
        // application is in maintenance mode, so we don't check that here.
        pageRef.set(page);
    };

    return Database;

})(jQuery, firebase);

/* vim: set ts=4 sw=4 et list: */
