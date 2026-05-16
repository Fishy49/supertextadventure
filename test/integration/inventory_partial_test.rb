# frozen_string_literal: true

require "test_helper"

class InventoryPartialTest < ActionView::TestCase
  include ClassicGameTestHelper

  test "renders ascii art block when item has ascii_art" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => { "name" => "Test Room", "description" => "A room.", "exits" => {} }
      },
      items: {
        "shiny" => {
          "name" => "shiny",
          "ascii_art" => "███\n░░░",
          "description" => "A shiny object."
        },
        "plain" => {
          "name" => "plain",
          "description" => "A plain object."
        }
      }
    )
    game = build_game(
      world_data: world,
      player_id: 1,
      player_state: player_state_in("room1", inventory: %w[shiny plain])
    )
    user = FakeUser.new(1)

    render template: "games/inventory", locals: { game: game, user: user }

    assert_includes rendered, "███"
    assert_select "li", 2
    assert_includes rendered, "border-double"
    assert_includes rendered, "— Inventory —"
    assert_select "pre", 1
  end

  test "renders empty-state ascii when inventory is empty" do
    world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => { "name" => "Test Room", "description" => "A room.", "exits" => {} }
      }
    )
    game = build_game(world_data: world, player_id: 1)
    user = FakeUser.new(1)

    render template: "games/inventory", locals: { game: game, user: user }

    assert_includes rendered, "thine sack lieth empty"
    assert_match(/<pre[^>]*>/, rendered)
  end
end
