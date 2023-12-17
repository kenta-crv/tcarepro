class AddStatusAndHistoryToRecruits < ActiveRecord::Migration[5.1]
  def change
    add_column :recruits, :status, :string
    add_column :recruits, :history, :text
  end
end
