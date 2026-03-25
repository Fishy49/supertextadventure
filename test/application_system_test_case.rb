# frozen_string_literal: true

require "test_helper"
require "capybara/cuprite"
require_relative "support/system_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, using: :chrome, screen_size: [1400, 1400],
                      options: { headless: ENV["CI"].present? || ENV["HEADLESS"].present?,
                                 browser_options: { "no-sandbox" => nil } }

  Capybara.default_max_wait_time = 5

  include SystemTestHelper
end
