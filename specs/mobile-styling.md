# Mobile Styline

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
