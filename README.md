# SuperTextAdventure

Welcome, ye adventurer!
SuperTextAdventure is three things:
1. An unglorified chat app.
2. A tool for telling stories with your friends.
3. The passion-project of a Ruby/Rails nerd.

The hope is that this application can provide a way to have a D&D-like experience in a nostalgic setting like the text-adventures of olde. It's also hoped that this application will provide a great example of what Rails 7 can do!

## Deploying
We recommend using [fly.io](https://fly.io/)! Simply clone the repo and run `fly launch` followed by `fly deploy`!

### ChatGPT
When running a game, you can use the `completions` API to generate text for your game. Simply get an API key from OpenAI.com add an `OPENAI_ACCESS_TOKEN` and an `OPENAI_ORGANIZATION_ID` variable to your `.env` file!

For Fly.io you can add this to your launched instance with
```
flyctl secrets set OPENAI_ACCESS_TOKEN=<TOKEN> OPENAI_ORGANIZATION_ID=<ORGANIZATION_ID>
```

## Running Locally
### Setup
Simply clone the repo and install with `./bin setup && rails db:migrate`.

### Running
The application can be run with `bundle exec ./bin/dev`.

## Roadmap

- ~Add HP~
- ~Add dice roller~
- ~Add loading of past message on scroll~ <-- (Launchable version!)
- ~Use OpenAI Completions to build prompts/descriptions~
- ~Create ChatGTP game mode and let ChatGPT run your game~
- ~Add ability for host to control who can type~
- Add basic inventory system
- Add ability for host to edit their messages or delete others
- Add browsable ASCII library
- Add "Strict" game mode that allows hosts to provide an allowlist of verbs that the "game" will accept
- Add friend system
- Add "Presence/Typing" indicators
