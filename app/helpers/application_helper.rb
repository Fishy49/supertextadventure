# frozen_string_literal: true

module ApplicationHelper
  def greeting
    greetings = [
      "Avast",
      "Haldo",
      "Ho There",
      "Good Morn",
      "Hail"
    ]

    greetings.sample
  end
end
