class StandardSheetItem < ApplicationRecord
  belongs_to :standard_stat_sheet
  belongs_to :standard_item
end