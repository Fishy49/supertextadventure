> PR: https://github.com/Fishy49/supertextadventure/pull/37

# Mobile Styling

The UI was designed to fit on a larger screen and does not work well on mobile devices. Ultimately this game should be very easy to play on a phone screen. The Tailwind styling used will need to be modfied so that the ENTIRE app is mobile-friendly.

This is challenging as the entire app was meant to be navigated via a text interface. This functionality needs to be maintained. For simplicity, the UI was designed with a static layout on all pages:
A header
A main content area
A text form
A sidebar
A footer

It is imperative that the functionality is preserved, but the layout does not need to remain static on mobile screens.

---

## Player-facing behaviour

The player should be able to navigate the app comfortably on a mobile screen. The UI should largely consist of a content area and a place to type in text much like a messaging app. Additional UI elements can be toggled via buttons. It should be simple and intuitive and CSS/Stimulus driven.

---

## Acceptance criteria

- The entire app should be navigable on a phone screen
- All elements should be scaled to fit and look attractive on a smaller screen
  - ASCII Art
  - Forms
- The hotkey footer doesn't need to exist and can be replaced with a mobile-friendly navigation menu
- The "terminal" style feel should be persisted (imagine an old terminal computer that worked on a small phone screen)
- System tests must be written to ensure a phone screen is still functional
- Updates can include changes to overall layout
- All styles must be in the context of Tailwind CSS
- Any UI interaction needs to be done using Stimulus controllers with standard conventions

## Constraints

- The existing functionality must not change unless critically necessary
- The current styling for larger screens should remain the same unless critically necessary
- Only use Stimulus controllers for any JS code needed
- Only use Tailwind CSS (v4 standards) for any style changes - avoid writing custom CSS

---

## Implementation plan

> Generated 2026-03-29

### 1. Files to create

| File | Purpose |
|------|---------|
| `app/javascript/controllers/mobile_nav_controller.js` | Stimulus controller that toggles a slide-out mobile navigation drawer (replaces the hotkey footer on small screens) and an expandable sidebar panel. |
| `app/views/application/_mobile_nav.html.erb` | Partial containing the mobile hamburger button and slide-out navigation drawer markup (Home, Tavern, About, Logout, owner links). |
| `test/system/mobile_test.rb` | System tests that run at a phone-sized viewport (375x667) verifying navigation, game play, sidebar toggle, and form usability. |
| `test/support/mobile_system_test_case.rb` | Base test case class for mobile system tests that configures Cuprite with a 375x667 screen size. |

### 2. Files to modify

| File | Changes |
|------|---------|
| **`app/assets/stylesheets/application.tailwind.css`** | (1) Add a responsive mobile grid layout inside `@layer base` using a `@media (max-width: 767px)` rule that stacks the grid areas vertically: `header / message-container / message-form / footer` (sidebar removed from flow). (2) On mobile, make `pre.text-xs` inside ASCII art wrappers use `overflow-x: auto` and a smaller `font-size: 0.55rem` to keep art viewable. (3) Reduce base font sizes on mobile via Tailwind's responsive utilities in the grid definition. |
| **`app/views/layouts/application.html.erb`** | (1) Add `md:grid-areas-layout` and a new `grid-areas-mobile` class so the mobile grid takes effect below `md` breakpoint. (2) Hide the sidebar div on mobile by default (`hidden md:block`), and wrap it in a container with a Stimulus-controlled slide-over panel for mobile. (3) Add `<%= render "mobile_nav" %>` before the footer. (4) Hide the footer on mobile (`hidden md:grid`). (5) On the message-form div, remove `pb-[150px]` on mobile and ensure it sticks to the bottom. (6) Add `overflow-hidden` on body for mobile to prevent double scrollbars. |
| **`app/views/application/_header.html.erb`** | (1) Reduce heading text to `text-lg md:text-xl` for mobile. (2) Truncate the greeting on very small screens using `truncate` class. |
| **`app/views/application/_footer.html.erb`** | (1) Add `hidden md:grid` to hide the entire hotkey footer on mobile (it will be replaced by the mobile nav drawer). |
| **`app/views/application/_mobile_nav.html.erb`** | (New file — see Files to create.) Contains a fixed-position bottom bar visible only on mobile (`md:hidden`) with: a hamburger/menu button to toggle the navigation drawer, and a sidebar toggle button (book/info icon) to reveal the sidebar as a slide-over panel. Uses `data-controller="mobile-nav"`. |
| **`app/javascript/controllers/mobile_nav_controller.js`** | (New file — see Files to create.) Stimulus controller with targets: `drawer`, `sidebar`, `overlay`. Actions: `toggleDrawer` (open/close nav links), `toggleSidebar` (slide sidebar panel in from the right), `closeAll`. Manages `translate-x-full` / `translate-x-0` transitions. |
| **`app/views/games/show.html.erb`** | (1) Ensure the sidebar content is duplicated or moved into a mobile-friendly slide-over container that the `mobile-nav` controller can toggle. Wrap the `content_for :sidebar` block so it also populates a mobile-visible panel. |
| **`app/views/shared/_terminal_input.html.erb`** | (1) On the contenteditable div, add responsive text sizing: `text-base md:text-lg`. (2) Ensure the prompt span doesn't overflow on narrow screens by adding `whitespace-nowrap`. |
| **`app/components/terminal_input_component.rb`** | (1) In `input_classes`, no changes needed — the ERB partial handles responsive classes. |
| **`app/views/ascii/_wrapper.html.erb`** | (1) Add `overflow-x-auto` and `max-w-full` to the outer div so ASCII art scrolls horizontally on narrow screens instead of breaking the layout. (2) Add `text-[0.55rem] md:text-xs` on the `<pre>` to scale ASCII art down on mobile. |
| **`app/views/games/_current_context.html.erb`** | (1) Add `max-w-full overflow-x-auto` to the context container so ASCII art inside the sidebar context box is scrollable on mobile. |
| **`app/views/games/_lobby.html.erb`** | (1) On the join form, ensure `text_field` and `text_area` inputs take `w-full` on mobile. No changes expected since they already use full width via base styles. |
| **`app/views/home/index.html.erb`** | (1) Add `px-2 md:px-0` for better mobile padding on the main content text. |
| **`app/views/games/index.html.erb`** | (1) Ensure the tavern layout renders well on mobile — the sidebar content (game list) needs to be accessible. Add a note/link or integrate with mobile sidebar toggle. |
| **`config/tailwind.config.js`** | (1) Add `screens` config to `theme.extend` if not already present to ensure `md` breakpoint is 768px (Tailwind default). No change actually needed since defaults apply, but verify. |
| **`test/application_system_test_case.rb`** | No changes — the default desktop size stays at 1400x1400. Mobile tests use their own base class. |

### 3. Implementation steps

**Step 1: Add mobile CSS grid layout**
- File: `app/assets/stylesheets/application.tailwind.css`
- Inside `@layer base`, add a `.grid-areas-mobile` class that defines a single-column grid:
  ```
  .grid-areas-mobile {
    grid-template-columns: 1fr;
    grid-template-rows: auto 1fr auto;
    grid-template-areas:
      "header"
      "message-container"
      "message-form";
  }
  ```
- The sidebar and footer grid areas are omitted on mobile — they'll be hidden or shown via overlay.

**Step 2: Update application layout for responsive grid**
- File: `app/views/layouts/application.html.erb`
- On `<body>`, change `grid-areas-layout` to `grid-areas-mobile md:grid-areas-layout`.
- On the message-container div, change `pb-[150px]` to `pb-4 md:pb-[150px]`.
- On the sidebar div, add `hidden md:block` to hide by default on mobile. Also add an `id="sidebar-panel"` and `data-mobile-nav-target="sidebar"` so the Stimulus controller can toggle it.
- Wrap sidebar in a fixed overlay container for mobile: when toggled, it slides in from the right over the content.
- On the footer, add `hidden md:grid` to hide on mobile.
- Add `<%= render "mobile_nav" %>` inside the body, before the closing `</body>`.

**Step 3: Create mobile navigation partial**
- File: `app/views/application/_mobile_nav.html.erb`
- Visible only on mobile (`md:hidden`).
- Fixed to the bottom of the screen, full width, with a dark background and terminal-green border-top.
- Contains two buttons: a hamburger icon (three lines via Unicode or simple text `[=]`) to open the nav drawer, and a sidebar icon (`[i]`) to open the sidebar overlay.
- The nav drawer is an overlay that slides up from the bottom with links: Home, Tavern, About, Logout (and owner-only: Invites, Worlds).
- Uses `data-controller="mobile-nav"` with appropriate targets and actions.
- Check `logged_in?` and `current_user.is_owner?` for conditional links (same logic as footer).

**Step 4: Create mobile-nav Stimulus controller**
- File: `app/javascript/controllers/mobile_nav_controller.js`
- `static targets = ["drawer", "sidebar", "overlay"]`
- `toggleDrawer()`: toggles the nav drawer visibility by adding/removing `translate-y-full` / `translate-y-0`.
- `toggleSidebar()`: clones or reveals the sidebar content into a fixed right-side panel, toggles `translate-x-full` / `translate-x-0`.
- `closeAll()`: closes both drawer and sidebar (called when overlay backdrop is clicked).
- All animations use Tailwind transition classes (`transition-transform duration-300`).

**Step 5: Make ASCII art mobile-friendly**
- File: `app/views/ascii/_wrapper.html.erb`
- Change the outer div from `class="w-fit mx-auto"` to `class="w-fit mx-auto max-w-full overflow-x-auto"`.
- Change `<pre>` from `class="text-xs"` to `class="text-[0.55rem] md:text-xs leading-tight md:leading-normal"`.

**Step 6: Make header responsive**
- File: `app/views/application/_header.html.erb`
- Change the `<h1>` from `text-xl` to `text-lg md:text-xl`.
- On the greeting `<h4>`, add `truncate` class to prevent overflow on narrow screens.

**Step 7: Hide footer on mobile**
- File: `app/views/application/_footer.html.erb`
- This is handled in Step 2 via the layout. The footer div already has `hidden md:grid` applied there.

**Step 8: Make sidebar content accessible on mobile for games/show**
- File: `app/views/games/show.html.erb`
- The `content_for :sidebar` block already populates the sidebar div. On mobile, this content will be inside the slide-over panel toggled by the mobile-nav controller. No duplicate content needed — the sidebar div exists in the DOM but is hidden until toggled.

**Step 9: Make game context area responsive**
- File: `app/views/games/_current_context.html.erb`
- Add `max-w-full` to the border container div to prevent overflow.

**Step 10: Adjust terminal input for mobile**
- File: `app/views/shared/_terminal_input.html.erb` and `app/components/terminal_input_component.html.erb`
- On the prompt `<span>`, add `whitespace-nowrap text-sm md:text-base`.
- On the contenteditable input div, ensure it doesn't overflow: the existing `max-w-full` class handles this.

**Step 11: Add mobile home page padding**
- File: `app/views/home/index.html.erb`
- Add `px-3 md:px-0` wrapper or apply to paragraphs so text has comfortable margins on mobile.

**Step 12: Create mobile system test base class**
- File: `test/support/mobile_system_test_case.rb`
- Subclass `ActionDispatch::SystemTestCase`.
- Configure `driven_by :cuprite` with `screen_size: [375, 667]` (iPhone SE dimensions).
- Include `SystemTestHelper`.

**Step 13: Write mobile system tests**
- File: `test/system/mobile_test.rb`
- Require `mobile_system_test_case`.
- Tests that verify:
  1. Home page renders and is navigable at 375x667.
  2. Login form is usable on mobile.
  3. Mobile nav drawer opens and contains navigation links.
  4. Sidebar toggle reveals sidebar content on mobile.
  5. Game page: terminal input is visible and functional (can type and submit commands).
  6. ASCII art does not break the layout (container scrolls).

### 4. Test plan

| # | Acceptance criterion | Test name | Setup | Input | Expected output |
|---|---------------------|-----------|-------|-------|-----------------|
| 1 | Entire app navigable on phone | `test "home page is navigable on mobile"` | Visit root at 375x667, user logged in | Click mobile nav hamburger, then click "Tavern" link | Page navigates to tavern; "Ye Olde Tavern" text visible |
| 2 | Elements scaled to fit (ASCII art) | `test "ascii art does not overflow on mobile"` | Visit root at 375x667, user logged in | Observe page | The ASCII art container has `overflow-x: auto`; no horizontal body scrollbar; `assert_selector "pre"` is visible |
| 3 | Elements scaled to fit (Forms) | `test "login form fits on mobile"` | Visit root at 375x667, not logged in | Fill in username and password, click Login | Login succeeds; form fields are visible and usable |
| 4 | Hotkey footer replaced with mobile nav | `test "hotkey footer hidden on mobile"` | Visit root at 375x667, user logged in | Observe page | `assert_no_selector "footer"` visible on screen (footer has `hidden md:grid`); mobile nav bar is visible at bottom |
| 5 | Terminal style preserved | `test "terminal green theme on mobile"` | Visit root at 375x667 | Observe page | Body has `bg-stone-800` and text is `terminal-green`; terminal input has blinking cursor styling |
| 6 | System tests for phone functionality | `test "can send game command on mobile"` | Create a dev game, visit at 375x667 | Type "look" in terminal input, press Enter | Game response with room description appears in message area |
| 7 | Sidebar accessible on mobile | `test "sidebar toggle works on mobile"` | Visit a game page at 375x667 | Click the sidebar toggle button in mobile nav | Sidebar content slides in; game name and player list visible |
| 8 | Stimulus controllers used for UI | `test "mobile nav drawer toggles"` | Visit root at 375x667, logged in | Click hamburger button | Nav drawer appears with Home, Tavern, About, Logout links; click hamburger again hides it |

### 5. Gotchas and constraints

- **Tailwind v4 / build pipeline**: The project uses `@tailwindcss/forms`, `@tailwindcss/typography`, and `@savvywombat/tailwindcss-grid-areas`. The custom grid-areas CSS in `application.tailwind.css` is hand-written, not from the plugin — so the mobile grid must also be hand-written in the same `@layer base` block. Do NOT rely on the `@savvywombat/tailwindcss-grid-areas` plugin for mobile layout.
- **Cuprite / Ferrum for mobile tests**: Cuprite uses Chrome DevTools Protocol. To simulate a mobile viewport, set `screen_size: [375, 667]` in `driven_by`. The browser will render at that size. There is no built-in "mobile emulation" mode in Cuprite, so tests rely on CSS media queries responding to the actual window width.
- **contenteditable input**: The terminal input uses `contenteditable` divs, not standard `<input>` elements. On mobile, this may behave differently with virtual keyboards. The existing `focus()` call in `terminal_controller.js` handles initial focus. Do not change this behavior — just ensure the input area is visible above the keyboard by keeping it at the bottom of the viewport.
- **pb-[150px] on message container**: This large bottom padding exists on desktop to ensure messages don't hide behind the fixed-position form. On mobile, with a stacked layout, this should be reduced to `pb-4` to prevent wasted space.
- **Turbo Stream / MutationObserver in game_controller.js**: The `game_controller.js` references `.grid-in-message-container` by class name. This class still exists on mobile (the grid area name doesn't change, just the grid definition does). Ensure the class remains on the message container div.
- **RuboCop rules**: Double-quoted strings enforced (`Style/StringLiterals`). Method max 60 lines. The new Ruby files (test support class) must follow these conventions.
- **No custom CSS**: The spec says "avoid writing custom CSS" and use Tailwind only. However, the grid-areas CSS is already custom in `application.tailwind.css`. The mobile grid definition is a necessary addition in the same pattern. All responsive styling on templates should use Tailwind utility classes (e.g., `hidden md:block`, `text-sm md:text-base`).
- **Sidebar on non-game pages**: Pages like Home, Tavern, About, and Setup all use `content_for :sidebar`. On mobile, this content should be accessible via the sidebar toggle. The sidebar div is in the layout, so the toggle will work for all pages.
- **Existing desktop layout must not change**: All changes use responsive prefixes (`md:`) to preserve the desktop experience. The mobile classes apply below the `md` breakpoint (768px).
- **Stimulus controller registration**: New controllers in `app/javascript/controllers/` are auto-discovered via `eagerLoadControllersFrom` in `index.js`. The file must be named `mobile_nav_controller.js` (underscores become hyphens in Stimulus: `data-controller="mobile-nav"`).
- **Footer links conditional logic**: The mobile nav must replicate the same conditional logic from `_footer.html.erb` — checking `logged_in?`, `current_user.is_owner?`, and the platform-specific symbol display. The mobile version can simplify by using text labels instead of hotkey symbols.
