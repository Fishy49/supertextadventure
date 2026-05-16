# frozen_string_literal: true

require "test_helper"

class InventoryPartialTest < ActionView::TestCase
  include ClassicGameTestHelper

  def setup
    @world = build_world(
      starting_room: "start",
      rooms: {
        "start" => { "name" => "Start Room", "description" => "A room.", "exits" => {} }
      },
      items: {
        "rusty_key" => {
          "name" => "Rusty Key",
          "description" => "A cold iron key.",
          "keywords" => %w[key rusty],
          "takeable" => true
        }
      }
    )
    @user = FakeUser.new(1)
    @game = build_game(
      world_data: @world,
      player_id: 1,
      player_state: player_state_in("start", inventory: ["rusty_key"])
    )
  end

  test "renders toggle button and hidden description" do
    render partial: "games/inventory", locals: { game: @game, user: @user }

    assert_match "click->inventory#toggle", rendered
    assert_match "aria-expanded=\"false\"", rendered
    assert_match "A cold iron key.", rendered
    assert_match(/class="hidden[^"]*"/, rendered)
  end

  test "renders ascii art block for items" do
    render partial: "games/inventory", locals: { game: @game, user: @user }

    assert_match "<pre", rendered
    assert_match "___", rendered
  end

  test "inventory card has visual border classes" do
    render partial: "games/inventory", locals: { game: @game, user: @user }

    assert_match(/class="[^"]*\bborder\b[^"]*"/, rendered)
    assert_match(/class="[^"]*\bborder-dashed\b[^"]*"/, rendered)
  end

  test "renders empty state when inventory is empty" do
    game = build_game(world_data: @world, player_id: 1, player_state: player_state_in("start", inventory: []))
    render partial: "games/inventory", locals: { game: game, user: @user }

    assert_match "(empty)", rendered
    assert_no_match "border-dashed", rendered
  end

  test "falls back to item_id when item has no name" do
    world = build_world(
      starting_room: "start",
      rooms: { "start" => { "name" => "Room", "description" => ".", "exits" => {} } },
      items: {}
    )
    game = build_game(
      world_data: world,
      player_id: 1,
      player_state: player_state_in("start", inventory: ["mystery_box"])
    )
    render partial: "games/inventory", locals: { game: game, user: @user }

    assert_match "mystery_box", rendered
  end
end
