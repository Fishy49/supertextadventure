# frozen_string_literal: true

class OnboardingService
  ONBOARDING_WORLD_NAME = "The Tipsy Dragon"

  CHARACTER_ADJECTIVES = %w[
    Brave Hapless Sneaky Dazzling Grumpy Jolly Bewildered
    Fearless Clumsy Legendary Plucky Gallant Wobbly Mighty
  ].freeze

  CHARACTER_NOUNS = %w[
    Thornbeard Mugwort Gloriana Bramblefist Moonwhisper
    Kettlebottom Ironbelly Stumbletoe Dragonbane Puddlejumper
    Copperpot Ashwick Rumblefoot Quillsworth Barrelhouse
  ].freeze

  def self.create_for(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    return if user_has_games?

    world = find_or_create_onboarding_world
    admin = User.find_by(is_owner: true)
    return unless admin && world

    game = create_game(world, admin)
    return unless game

    create_game_user(game)
    game
  end

  private

    def user_has_games?
      @user.game_users.exists? || @user.hosted_games.exists?
    end

    def find_or_create_onboarding_world
      World.find_by(name: ONBOARDING_WORLD_NAME)
    end

    def create_game(world, admin)
      Game.create!(
        name: "#{@user.username}'s First Adventure",
        description: "You wake up in a tavern cellar with no memory and an enormous tab to settle.",
        created_by: admin.id,
        game_type: :classic,
        status: :closed,
        max_players: 1,
        world: world,
        enable_hp: true,
        starting_hp: 20,
        host_display_name: "The Narrator"
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      Rails.logger.error("OnboardingService: Failed to create game: #{e.message}")
      nil
    end

    def create_game_user(game)
      game.game_users.create!(
        user: @user,
        character_name: random_character_name
      )
    end

    def random_character_name
      "#{CHARACTER_ADJECTIVES.sample} #{CHARACTER_NOUNS.sample}"
    end
end
