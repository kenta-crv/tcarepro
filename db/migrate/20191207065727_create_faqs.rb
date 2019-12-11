class CreateFaqs < ActiveRecord::Migration[5.1]
  def change
    create_table :faqs do |t|
      t.references :crm, foreign_key: true
      t.string :question
      t.string :select
      t.string :answer
      t.timestamps
    end
  end
end
