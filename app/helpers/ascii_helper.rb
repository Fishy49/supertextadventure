# frozen_string_literal: true

module AsciiHelper
  def ascii(partial_name)
    render "/ascii/wrapper", partial_name: partial_name
  end
end
