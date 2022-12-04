# frozen_string_literal: true

class DiceRoll
	VALID_DICE = %w[4 6 8 10 12 20 100]
	attr_accessor :result_dice
	attr_accessor :modifiers

	def initialize(dice_strings, modifiers = nil)
		@modifiers = modifiers.presence || []
		@result_dice = parse_dice_strings(dice_strings)
	end

	def parse_dice_strings(dice_strings)
		rolls = []

		dice_strings.each do |dice_string|
			next unless dice_string.include?('d')
			count, die = dice_string.split('d')
			next unless VALID_DICE.include?(die) || count.to_i&.zero?
		  rolls << [count, die]
		end

		results = []
		rolls.each do |roll|
		  roll.first.to_i.times do
		      results << [rand(1..roll.last.to_i), roll.last]
		  end
		end

	  results
	end

	def modifiers_total
		@modifiers.sum(&:to_i)
	end

	def total
		dice_total = @result_dice.sum(&:first)
		dice_total + modifiers_total
	end
end
