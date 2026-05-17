# frozen_string_literal: true

require "test_helper"

class InventoryViewTest < ActionView::TestCase
  include ClassicGameTestHelper

  FakeUser = Struct.new(:id)

  setup do
    @world = build_world(
      starting_room: "room1",
      rooms: {
        "room1" => { "name" => "Room", "description" => "A room.", "exits" => {} }
      },
      items: {
        "rusty_key"      => { "name" => "Rusty Key",      "keywords" => %w[key rusty],    "description" => "An old key."           },
        "health_potion"  => { "name" => "Health Potion",  "keywords" => %w[potion health], "description" => "A red potion."        },
        "enchanted_blade"=> { "name" => "Enchanted Blade","keywords" => %w[blade sword],   "description" => "Hums with magic."     },
        "ancient_scroll" => { "name" => "Ancient Scroll", "keywords" => %w[scroll],        "description" => "Covered in runes."   },
        "sparkling_gem"  => { "name" => "Sparkling Gem",  "keywords" => %w[gem],           "description" => "Glows faintly."      },
        "victory_crown"  => { "name" => "Victory Crown",  "keywords" => %w[crown],         "description" => "The crown."          }
      }
    )
  end

  test "renders empty inventory with placeholder" do
    game = build_game(world_data: @world, player_id: 1)
    user = FakeUser.new(1)

    html = render_partial(game, user)
    assert_includes html, "(empty)"
    assert_not_includes html, "data-controller=\"inventory\""
  end

  test "renders inventory list with toggle buttons" do
    game = build_game(
      world_data: @world,
      player_id: 1,
      player_state: player_state_in("room1", inventory: %w[rusty_key health_potion])
    )
    user = FakeUser.new(1)

    html = render_partial(game, user)
    assert_includes html, "data-controller=\"inventory\""
    assert_includes html, "Rusty Key"
    assert_includes html, "Health Potion"
    assert_includes html, "data-inventory-target=\"toggle\""
    assert_includes html, "aria-expanded=\"false\""
  end

  test "details panels are hidden by default" do
    game = build_game(
      world_data: @world,
      player_id: 2,
      player_state: player_state_in("room1", inventory: ["rusty_key"])
    )
    user = FakeUser.new(2)

    html = render_partial(game, user)
    assert_includes html, "data-inventory-target=\"details\""
    assert_match(/hidden/, html)
  end

  test "details panel id follows naming convention" do
    game = build_game(
      world_data: @world,
      player_id: 5,
      player_state: player_state_in("room1", inventory: %w[rusty_key health_potion])
    )
    user = FakeUser.new(5)

    html = render_partial(game, user)
    assert_includes html, "inventory_details_5_0"
    assert_includes html, "inventory_details_5_1"
  end

  test "aria-controls links button to details panel" do
    game = build_game(
      world_data: @world,
      player_id: 3,
      player_state: player_state_in("room1", inventory: ["rusty_key"])
    )
    user = FakeUser.new(3)

    html = render_partial(game, user)
    assert_includes html, "aria-controls=\"inventory_details_3_0\""
    assert_includes html, "id=\"inventory_details_3_0\""
  end

  test "renders item description inside details panel" do
    game = build_game(
      world_data: @world,
      player_id: 4,
      player_state: player_state_in("room1", inventory: ["rusty_key"])
    )
    user = FakeUser.new(4)

    html = render_partial(game, user)
    assert_includes html, "An old key."
  end

  test "renders pre element for ASCII art" do
    game = build_game(
      world_data: @world,
      player_id: 6,
      player_state: player_state_in("room1", inventory: ["rusty_key"])
    )
    user = FakeUser.new(6)

    html = render_partial(game, user)
    assert_includes html, "<pre"
  end

  test "renders sword ASCII art for blade item" do
    game = build_game(
      world_data: @world,
      player_id: 7,
      player_state: player_state_in("room1", inventory: ["enchanted_blade"])
    )
    user = FakeUser.new(7)

    html = render_partial(game, user)
    assert_includes html, "Enchanted Blade"
    assert_includes html, "<pre"
  end

  test "renders multiple different item types" do
    game = build_game(
      world_data: @world,
      player_id: 8,
      player_state: player_state_in("room1", inventory: %w[rusty_key health_potion sparkling_gem victory_crown])
    )
    user = FakeUser.new(8)

    html = render_partial(game, user)
    assert_includes html, "Rusty Key"
    assert_includes html, "Health Potion"
    assert_includes html, "Sparkling Gem"
    assert_includes html, "Victory Crown"
  end

  private

    def render_partial(game, user)
      render partial: "games/inventory", locals: { game: game, user: user }
    end
end
