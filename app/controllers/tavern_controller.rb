# frozen_string_literal: true

class TavernController < ApplicationController
  def index
    redirect_to root_url, notice: "Away with ye! The tavern is for adventurers only!" unless logged_in?
  end
end
