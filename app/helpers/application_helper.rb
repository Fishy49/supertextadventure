# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def greeting
    greetings = [
      "Avast",
      "Haldo",
      "Ho There",
      "Good Morn",
      "Hail",
      "Greetums",
      "Frabjous Day",
      "Jingle Jangle",
      "Huzzah"
    ]

    greetings.sample
  end

  def loading_message
    messages = [
      "Parsing Text",
      "Degaussing",
      "Calibrating Scan Lines",
      "Attaching Texticles",
      "Filling The Mugs",
      "Sharpening The Swords",
      "Marking The Maps",
      "Opening The Taverns",
      "Encouraging The Dwarves",
      "Practicing Our \"Huzzah\"'s"
    ]

    messages.sample
  end
end
