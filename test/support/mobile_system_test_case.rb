# frozen_string_literal: true

require "test_helper"
require "capybara/cuprite"
require_relative "system_test_helper"

class MobileSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, using: :chrome, screen_size: [375, 667],
                      options: { headless: ENV["CI"].present? || ENV["HEADLESS"].present?,
                                 browser_path: ENV.fetch("BROWSER_PATH", nil),
                                 pending_connection_errors: false,
                                 process_timeout: 30,
                                 browser_options: { "no-sandbox" => nil } }

  Capybara.default_max_wait_time = 10

  include SystemTestHelper
end
