class AddColumnToAgree < ActiveRecord::Migration[5.1]
  def change
    add_column :recruits, :tel, :string
    
    add_column :recruits, :agree_1, :string
    add_column :recruits, :agree_2, :string
    add_column :recruits, :emergency_name, :string
    add_column :recruits, :emergency_relationship, :string
    add_column :recruits, :emergency_tel, :string

    add_column :recruits, :identification, :string

    add_column :recruits, :bank, :string
    add_column :recruits, :branch, :string
    add_column :recruits, :bank_number, :string
    add_column :recruits, :bank_name, :string
  end
end
