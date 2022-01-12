# frozen_string_literal: true

module ApplicationHelper
  def greeting
    greetings = [
      "AVAST",
      "HALDO",
      "HO THERE",
      "M'LORD",
      "SIRE"
    ]

    greetings.sample
  end
end
