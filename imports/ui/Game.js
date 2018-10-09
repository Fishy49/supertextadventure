import React, { Component } from 'react';
import { Meteor } from 'meteor/meteor';
import classnames from 'classnames';
 
import { Games } from '../api/games.js';

// Game component - represents a single Game item
export default class Game extends Component {
 
  deleteThisGame() {
    Meteor.call('games.remove', this.props.game._id);
  }

  togglePrivate() {
    Meteor.call('games.setPrivate', this.props.game._id, ! this.props.game.private);
  }

  render() {
    // Give games a different className when they are private,
    // so that we can style them nicely in CSS
    const gameClassName = classnames({
      private: this.props.game.private,
    });

    return (
      <li className={gameClassName}>
        <button className="delete" onClick={this.deleteThisGame.bind(this)}>
          &times;
        </button>

        { this.props.showPrivateButton ? (
          <button className="toggle-private" onClick={this.togglePrivate.bind(this)}>
            { this.props.game.private ? 'Private' : 'Public' }
          </button>
        ) : ''}
 
        <span className="text">
          <strong>{this.props.game.username}</strong>: {this.props.game.text}
        </span>
      </li>
    );
  }
}