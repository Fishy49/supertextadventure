# supertextadventure.com

The public site: the landing page plus the Classic Game Engine docs. It lives
in this directory and deploys separately from the Rails app as a free
DigitalOcean App Platform static site. Commands below run from `site/`.

## Building

```sh
npm install   # once; installs the Tailwind CLI
bin/build
```

Rendering is stdlib Ruby. The `Gemfile` here is intentionally empty; it only
exists so DigitalOcean detects Ruby. The one real dependency is the Tailwind
CLI in `package.json`. Output goes to `dist/` (gitignored):

- `views/home.erb` and `views/404.erb`, wrapped in `views/layout.erb`
- `views/docs/*.erb`, wrapped in `views/docs_layout.erb`, written as
  `docs/<slug>/index.html` (overview is `docs/index.html`)
- `css/input.css` compiled to `css/main.css` (Tailwind v4 scans `views/`
  for classes, so nothing to configure when adding markup)
- everything in `public/`, copied as-is

Preview locally with any static file server, for example:

```sh
python3 -m http.server 4567 -d dist
```

## Deploying

`.do/site.yaml` at the repo root describes the DigitalOcean app: source
directory `site`, build command `ruby bin/build`, output directory `dist`,
`404.html` as the error document, and `supertextadventure.com` as the
primary domain. Create it with `doctl apps create --spec .do/site.yaml`.
DigitalOcean installs the npm dependencies itself before running the build
command, and every push to `main` redeploys.

DNS is at DNSimple, so after creating the app, point the apex at the app's
default `ondigitalocean.app` hostname with an ALIAS record. The certificate
issues once that resolves.

## Generating `public/builder/`

`bin/build-builder` assembles the offline World Builder page from the Rails
app's builder sources, the validation contract, and the shipped games in
`games/`. Commit the output.

```sh
bin/build-builder
```

## Generating `public/contract/`

`bin/build-contract` copies the world validation contract (JSON Schema, refs
table, and the valid/invalid fixture corpus) from the Rails app into
`public/contract/` and writes an `index.json`. Commit the output; the
DigitalOcean build cannot reach the app directory.

```sh
bin/build-contract
```

## Generating `public/llms.txt`

`bin/build-llms` converts the ERB docs in `views/docs/` into a single
`public/llms.txt` file for LLM consumption. It's pure stdlib Ruby.

```sh
bin/build-llms
```

### Pre-commit hook

`githooks/pre-commit` at the repo root runs `site/bin/build-llms`
automatically whenever a commit touches `site/views/docs/*.erb` or the
script itself, and stages the regenerated `site/public/llms.txt` alongside
the commit.

Install once per clone, from the repo root:

```sh
git config core.hooksPath githooks
```

Bypass for a single commit with `git commit --no-verify`.
