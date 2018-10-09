import { Meteor } from 'meteor/meteor';
import { Mongo } from 'meteor/mongo';
import { check } from 'meteor/check';
 
export const Games = new Mongo.Collection('games');

if (Meteor.isServer) {
  // This code only runs on the server
  // Only publish games that are public or belong to the current user
  Meteor.publish('games', function gamesPublication() {
    return Games.find({
      $or: [
        { private: { $ne: true } },
        { owner: this.userId },
      ],
    });
  });
}

Meteor.methods({
  'games.insert'(text) {
    check(text, String);
 
    // Make sure the user is logged in before inserting a game
    if (! this.userId) {
      throw new Meteor.Error('not-authorized');
    }
 
    Games.insert({
      text,
      createdAt: new Date(),
      owner: this.userId,
      username: Meteor.users.findOne(this.userId).username,
    });
  },
  'games.remove'(gameId) {
    check(gameId, String);

    const game = Games.findOne(gameId);
    if (game.private && game.owner !== this.userId) {
      // If the game is private, make sure only the owner can delete it
      throw new Meteor.Error('not-authorized');
    }
 
    Games.remove(gameId);
  },
  'games.setPrivate'(gameId, setToPrivate) {
    check(gameId, String);
    check(setToPrivate, Boolean);
 
    const game = Games.findOne(gameId);
 
    // Make sure only the game owner can make a game private
    if (game.owner !== this.userId) {
      throw new Meteor.Error('not-authorized');
    }
 
    Games.update(gameId, { $set: { private: setToPrivate } });
  },
});