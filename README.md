# SuperTextAdventure

Welcome, ye adventurer!
SuperTextAdventure is three things:
1. An unglorified chat app.
2. A tool for telling stories with your friends.
3. The passion-project of a Ruby/Rails nerd.

The hope is that this application can provide a way to have a D&D-like experience in a nostalgic setting like the text-adventures of olde. It's also hoped that this application will provide a great example of what Rails 7 can do!

## Setup
Simply clone the repo and install with `bundle install && rails db:create && rails db:migrate`.

## Running
The application can be run with `rails s`. Clockwork is used to run background jobs to cleanup any lingering "online" or "is typing" indicators. This can be run with `bundle exec clockwork clock.rb`

## TODO

- ~~Add "Presence/Typing" indicators~~
- Add HP
- Add ability for host to control who can type
- Add basic inventory system
- Add loading of past message on scroll <-- (Launchable version!)
- Add ability for host to edit their messages
- Add browsable ASCII library
- Add "Strict" game mode that allows hosts to provide an allowlist of verbs that the "game" will accept
- Add friend system
- Add dice roller
