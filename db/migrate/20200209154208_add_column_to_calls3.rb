class AddColumnToCalls3 < ActiveRecord::Migration[5.1]
  def change
    add_reference :calls, :tel, :bigint, index: true
    add_foreign_key :calls, :customers, column: :tel
  end
end
