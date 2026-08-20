# frozen_string_literal: true

class AddUniqueIndexToWorldsName < ActiveRecord::Migration[8.0]
  class MigrationWorld < ActiveRecord::Base
    self.table_name = "worlds"
  end

  def up
    # Clean up existing duplicate name rows so the unique index can be created.
    MigrationWorld.where.not(name: nil).group(:name).having("COUNT(*) > 1").pluck(:name).each do |name|
      ids = MigrationWorld.where(name: name).order(:id).pluck(:id)
      canonical_id = ids.first
      duplicate_ids = ids.drop(1)

      execute(ActiveRecord::Base.sanitize_sql_array(
                ["UPDATE games SET world_id = ? WHERE world_id IN (?)", canonical_id, duplicate_ids]
              ))
      MigrationWorld.where(id: duplicate_ids).delete_all
    end

    add_index :worlds, :name, unique: true
  end

  def down
    remove_index :worlds, :name
  end
end
