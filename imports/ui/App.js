import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import { Meteor } from 'meteor/meteor';
import { withTracker } from 'meteor/react-meteor-data';

import { Games } from '../api/games.js';

import Game from './Game.js';
import AccountsUIWrapper from './AccountsUIWrapper.js';
 
// App component - represents the whole app
class App extends Component {
  constructor(props) {
    super(props);
 
    this.state = {
      // hideCompleted: false,
    };
  }

  
  renderGames() {
    let filteredGames = this.props.games;
    // if (this.state.hideCompleted) {
      // filteredGames = filteredGames.filter(game => !game.checked);
    // }
    return filteredGames.map((game) => {
      const currentUserId = this.props.currentUser && this.props.currentUser._id;
 
      return (
        <Game
          key={game._id}
          game={game}
        />
      );
    });
  }
 
  render() {
    return (
      <div className="container">
        <header>
          <h1 className="title">Super Text Adventure</h1>

          { this.props.currentUser ?
              <ul>
                {this.renderGames()}
              </ul>
            : <AccountsUIWrapper />
          }
        </header>
      </div>
    );
  }
}

export default withTracker(() => {
  Meteor.subscribe('games');

  return {
    games: Games.find({}, { sort: { createdAt: -1 } }).fetch(),
    currentUser: Meteor.user(),
  };
})(App);