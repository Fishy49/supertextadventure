# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    enable_extension :citext

    create_table :users do |t|
      t.citext :username
      t.string :password_digest

      t.timestamps

      t.index [:username], unique: true
    end
  end
end
