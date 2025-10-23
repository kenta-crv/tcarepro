class EmergencyCreateMissingTables < ActiveRecord::Migration[5.1]
  def up
    # Only create tables if they don't exist
    return if ActiveRecord::Base.connection.table_exists?('admins')
    
    puts "EMERGENCY: Creating missing database tables..."
    
    create_table :admins do |t|
      t.string :user_name, default: "", null: false
      t.string :email, default: "", null: false
      t.string :encrypted_password, default: "", null: false
      t.string :select
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    create_table :senders do |t|
      t.string :user_name, default: "", null: false
      t.string :email, default: "", null: false
      t.string :encrypted_password, default: "", null: false
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.integer :rate_limit
      t.integer :default_inquiry_id
      t.string :url
    end

    create_table :inquiries do |t|
      t.string :headline
      t.string :from_company
      t.string :person
      t.string :person_kana
      t.string :from_tel
      t.string :from_fax
      t.string :from_mail
      t.string :url
      t.string :address
      t.string :title
      t.string :content
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.integer :sender_id
    end

    create_table :customers do |t|
      t.string :company
      t.string :store
      t.string :first_name
      t.string :last_name
      t.string :first_kana
      t.string :last_kana
      t.string :tel
      t.string :tel2
      t.string :fax
      t.string :mobile
      t.string :industry
      t.string :mail
      t.string :url
      t.string :people
      t.string :postnumber
      t.string :address
      t.string :caption
      t.string :remarks
      t.string :status
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    create_table :contact_trackings do |t|
      t.string :code, null: false
      t.integer :customer_id, null: false
      t.integer :inquiry_id, null: false
      t.integer :sender_id
      t.integer :worker_id
      t.string :status, null: false
      t.string :contact_url
      t.datetime :sended_at
      t.datetime :callbacked_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    puts "EMERGENCY: Essential tables created successfully!"
  end

  def down
    # Safety - don't drop tables in emergency migration
    puts "EMERGENCY: Migration down - skipping table drops for safety"
  end
end