# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "https://ga.jspm.io/npm:@hotwired/turbo-rails@7.2.4/app/javascript/turbo/index.js"
pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.2.1/dist/stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.8/src/index.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "lodash.debounce", to: "https://ga.jspm.io/npm:lodash.debounce@4.0.8/index.js"
pin "@hotwired/turbo", to: "https://ga.jspm.io/npm:@hotwired/turbo@7.2.4/dist/turbo.es2017-esm.js"
pin "@rails/actioncable/src", to: "https://ga.jspm.io/npm:@rails/actioncable@7.0.4/src/index.js"

# CodeMirror 6 for JSON editing with syntax highlighting and folding
pin "codemirror", to: "https://ga.jspm.io/npm:codemirror@6.0.1/dist/index.js"
pin "@codemirror/lang-json", to: "https://ga.jspm.io/npm:@codemirror/lang-json@6.0.1/dist/index.js"
pin "@codemirror/language", to: "https://ga.jspm.io/npm:@codemirror/language@6.10.3/dist/index.js"
pin "@codemirror/state", to: "https://ga.jspm.io/npm:@codemirror/state@6.4.1/dist/index.js"
pin "@codemirror/view", to: "https://ga.jspm.io/npm:@codemirror/view@6.34.1/dist/index.js"
pin "@codemirror/commands", to: "https://ga.jspm.io/npm:@codemirror/commands@6.7.1/dist/index.js"
pin "@codemirror/search", to: "https://ga.jspm.io/npm:@codemirror/search@6.5.7/dist/index.js"
pin "@codemirror/autocomplete", to: "https://ga.jspm.io/npm:@codemirror/autocomplete@6.18.1/dist/index.js"
pin "@codemirror/lint", to: "https://ga.jspm.io/npm:@codemirror/lint@6.8.2/dist/index.js"
pin "@lezer/common", to: "https://ga.jspm.io/npm:@lezer/common@1.2.2/dist/index.js"
pin "@lezer/highlight", to: "https://ga.jspm.io/npm:@lezer/highlight@1.2.1/dist/index.js"
pin "@lezer/lr", to: "https://ga.jspm.io/npm:@lezer/lr@1.4.2/dist/index.js"
pin "@lezer/json", to: "https://ga.jspm.io/npm:@lezer/json@1.0.2/dist/index.js"
pin "style-mod", to: "https://ga.jspm.io/npm:style-mod@4.1.2/src/style-mod.js"
pin "w3c-keyname", to: "https://ga.jspm.io/npm:w3c-keyname@2.2.8/index.js"
pin "crelt", to: "https://ga.jspm.io/npm:crelt@1.0.6/index.js"
