class AddColumnToCrm < ActiveRecord::Migration[5.1]
  def change
    add_column :crms, :date_time, :datetime
  end
end
