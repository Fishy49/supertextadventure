# frozen_string_literal: true

class TerminalInputComponent < ViewComponent::Base
  def initialize(prompt:, stimulus_controllers: [], stimulus_values: {})
    super

    @terminal_prompt = prompt
    @stimulus_controllers = stimulus_controllers
    @stimulus_controllers << "terminal" unless @stimulus_controllers.include?("terminal")
    @stimulus_values = stimulus_values
  end

  private

    def input_capture_actions
      @stimulus_controllers.map { |c| "keydown->#{c}#capture_input" }.join(" ")
    end

    def stimulus_targets_for(target_value)
      @stimulus_controllers.map { |c| "data-#{c}-target=#{target_value}" }.join(" ")
    end

    def input_classes
      classes(
        "terminal-input",
        "inline-block",
        "min-w-[5px]",
        "max-w-full",
        "uppercase",
        "caret-transparent",
        "relative",
        "outline-none",
        "align-bottom",
        "after:bg-terminal-green",
        "after:w-[12px]",
        "after:h-[24px]",
        "after:absolute",
        "after:bottom-[2px]",
        "after:hidden",
        "after:animate-blink",
        "after:focus:inline-block",
        "focus-visible:outline-none",
        "after:focus-visible:outline-none"
      )
    end
end
