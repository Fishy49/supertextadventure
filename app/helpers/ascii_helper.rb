# frozen_string_literal: true

module AsciiHelper
  def ascii(name)
    render "/ascii/#{name}"
  end
end
