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
end
