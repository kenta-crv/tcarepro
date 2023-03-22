class CreateAutoformResults < ActiveRecord::Migration[5.1]
  def change
    create_table :autoform_results do |t|

      t.integer :customer_id
      t.integer :sender_id
      t.integer :worker_id
      t.integer :success_sent
      t.integer :failed_sent
      t.timestamps
    end
  end
end
