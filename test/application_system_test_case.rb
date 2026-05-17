# frozen_string_literal: true

require "test_helper"
require "capybara/cuprite"
require_relative "support/system_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, using: :chrome, screen_size: [1400, 1400],
                      options: { headless: ENV["CI"].present? || ENV["HEADLESS"].present?,
                                 browser_path: ENV.fetch("BROWSER_PATH", nil),
                                 pending_connection_errors: false,
                                 process_timeout: 30,
                                 browser_options: { "no-sandbox" => nil } }

  Capybara.default_max_wait_time = 10

  include SystemTestHelper

  # The Capybara/Cuprite driver is shared across the test process. Mobile system
  # tests call page.driver.resize(375, 667), and Capybara only resets sessions
  # between tests — not the browser window size. When a mobile test runs before
  # an ApplicationSystemTestCase test (random seed order), the desktop test
  # inherits the 375x667 viewport and the sidebar (hidden md:block) stays
  # hidden. Force the desktop viewport back at the start of every test.
  setup do
    page.driver.resize(1400, 1400)
  end
end
