# frozen_string_literal: true

class MessageComponent < ViewComponent::Base
  def initialize(message:, current_user:)
    super

    @message = message
    @user = current_user
  end

  def container_classes
    classes(
      "game-message": true,
      "text-bold": !@message.player_message? && @message.game_user&.user == @user,
      "text-white host-message py-2 pl-5": @message.host_message? && !@message.event?
    )
  end

  def inventory_message?
    @message.content.to_s.start_with?("=== INVENTORY ===")
  end

  def format_inventory_html(content)
    parts = split_inventory_parts(content)
    safe_join(parts.map { |part| render_inventory_part(part) })
  end

  private

    def split_inventory_parts(content)
      parts = []
      buffer = []

      content.split("\n").each do |line|
        if line.match?(/^\[.+\]$/) && buffer.any?
          parts << buffer.dup
          buffer = [line]
        else
          buffer << line
        end
      end
      parts << buffer unless buffer.empty?
      parts
    end

    def render_inventory_part(lines)
      if lines.first&.match?(/^\[.+\]$/)
        render_item_part(lines)
      else
        content_tag(:div, lines.join("\n"), class: "whitespace-pre-wrap")
      end
    end

    def render_item_part(lines)
      name_line = lines[0]
      rest = lines[1..] || []

      art_end = rest.index { |l| l.present? && !l.start_with?("  ") } || rest.length
      art_text = rest[0...art_end].join("\n")
      detail_text = rest[art_end..].compact_blank.join("\n")

      content_tag(:div, class: "inventory-item", data: { action: "click->inventory#toggle" }) do
        content_tag(:div, name_line, class: "font-bold") +
          content_tag(:div, data: { inventory_detail: true }, class: "inventory-detail hidden") do
            content_tag(:pre, art_text, class: "text-xs leading-tight") +
              content_tag(:p, detail_text)
          end
      end
    end
end
