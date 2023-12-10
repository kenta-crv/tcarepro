class AddContractIdCustomer < ActiveRecord::Migration[5.1]
  def change
    add_reference :contracts, :customer, foreign_key: true
  end
end
