# frozen_string_literal: true

module WorldsHelper
  # JSON for a <script type="application/json"> tag: escapes anything that could close the tag.
  def builder_json(data)
    ERB::Util.json_escape(data.to_json).html_safe # rubocop:disable Rails/OutputSafety
  end
end
