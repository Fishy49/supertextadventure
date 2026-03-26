# SuperTextAdventure

Welcome, ye adventurer!
SuperTextAdventure is three things:
1. An unglorified chat app.
2. A tool for telling stories with your friends.
3. The passion-project of a Ruby/Rails nerd.

The hope is that this application can provide a way to have a D&D-like experience in a nostalgic setting like the text-adventures of olde or even play a classic text-adventure!

This app currently supports a JSON format that allows single or multiplyer text adventures.
Additionally, this app supports a chat-like interface with a few handy tools (Dice rolling, health, inventory) so you can build your own adventure.

## Running Locally
### Setup
Simply clone the repo and install with `./bin setup && rails db:migrate`.

### Running
The application can be run with `bundle exec ./bin/dev`.

## Game Modes
All modes use the same interface which is a free-text field that allows the player to interact with the game.

1. **Classic Text Adventure** - a JSON powered text adventure that defines an entire world. Rather than pitting your skills against an AI or a human, this is a deterministic text-adventure and the format of the JSON file supports complex and rich gameplay
2. **Chat Mode** - A simple chat interface where a "host" is designated and "runs" the game while players talk their way through the game. The idea is that the host will run things similar to a D&D game but role-play as a text-parser.
3. **AI Host** - This is still a concept-in-progress but the idea is that a Classic Text Adventure game file could be run by an LLM to enrich descriptions and perhaps add content on the fly.

## Current State of Development
This is an older app that is being rewritten and used as a testbed for agentic development utilizing a software-factory pattern.

Specs are writting in markdown in the `/specs` folder and committed to main. A daily job picks up these specs and processes them into a reviewable PR.
This is very much a work-in-progress and certain app code might be orphaned/outdated while the application is restructured.

## QA Mode
Getting the app running and navigating to `/dev/game` will fire up a QA world that is small but representative of a lot of what can be done in the classic game engine. This world isn't really meant to be "fun" but allows you to quickly test things:
<img width="1645" height="959" alt="image" src="https://github.com/user-attachments/assets/edd9a96d-d224-4347-95d3-539d4de9073d" />

