# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.8/src/index.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "lodash.debounce", to: "https://ga.jspm.io/npm:lodash.debounce@4.0.8/index.js"
pin "@hotwired/turbo", to: "turbo.min.js"
pin "@rails/actioncable/src", to: "https://ga.jspm.io/npm:@rails/actioncable@7.0.4/src/index.js"

# CodeMirror 6 for JSON editing with syntax highlighting and folding
pin "codemirror" # @6.0.2
pin "@codemirror/lang-json", to: "https://ga.jspm.io/npm:@codemirror/lang-json@6.0.1/dist/index.js"
pin "@codemirror/language", to: "@codemirror--language.js" # @6.12.1
pin "@codemirror/state", to: "@codemirror--state.js" # @6.5.4
pin "@codemirror/view", to: "@codemirror--view.js" # @6.39.11
pin "@codemirror/commands", to: "@codemirror--commands.js" # @6.10.1
pin "@codemirror/search", to: "@codemirror--search.js" # @6.6.0
pin "@codemirror/autocomplete", to: "@codemirror--autocomplete.js" # @6.20.0
pin "@codemirror/lint", to: "@codemirror--lint.js" # @6.9.3
pin "@lezer/common", to: "@lezer--common.js" # @1.5.0
pin "@lezer/highlight", to: "@lezer--highlight.js" # @1.2.3
pin "@lezer/lr", to: "https://ga.jspm.io/npm:@lezer/lr@1.4.2/dist/index.js"
pin "@lezer/json", to: "https://ga.jspm.io/npm:@lezer/json@1.0.2/dist/index.js"
pin "style-mod" # @4.1.3
pin "w3c-keyname" # @2.2.8
pin "crelt" # @1.0.6
pin "@marijn/find-cluster-break", to: "@marijn--find-cluster-break.js" # @1.0.2
