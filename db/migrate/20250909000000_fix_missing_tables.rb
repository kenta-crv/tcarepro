class FixMissingTables < ActiveRecord::Migration[5.1]
  def up
    # Recreate all tables that are missing
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
      t.index [:email], name: "index_admins_on_email", unique: true
      t.index [:reset_password_token], name: "index_admins_on_reset_password_token", unique: true
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
      t.string :choice
      t.string :title
      t.string :other
      t.string :url_2
      t.string :inflow
      t.string :business
      t.string :price
      t.string :number
      t.string :history
      t.string :area
      t.string :target
      t.date :start
      t.string :contact_url
      t.string :meeting
      t.string :experience
      t.string :extraction_count
      t.string :send_count
      t.integer :worker_id
      t.string :genre
      t.string :forever
      t.string :customers_code
      t.integer :industry_code
      t.string :company_name
      t.string :payment_date
      t.string :industry_mail
      t.integer :worker_update_count_day
      t.integer :worker_update_count_week
      t.integer :worker_update_count_month
      t.datetime :next_date
      t.index [:created_at], name: "index_customers_on_created_at"
      t.index [:worker_id], name: "index_customers_on_worker_id"
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
      t.datetime :scheduled_date
      t.string :callback_url
      t.string :customers_code
      t.string :auto_job_code
      t.datetime :sending_started_at
      t.datetime :sending_completed_at
      t.text :response_data
      t.integer :submission_attempts, default: 1
      t.text :failure_reason
      t.string :detection_method
      t.string :generation_code
      t.string :session_code
      t.index [:auto_job_code], name: "index_contact_trackings_on_auto_job_code"
      t.index [:code], name: "index_contact_trackings_on_code", unique: true
      t.index [:customer_id, :inquiry_id, :sender_id, :worker_id], name: "index_contact_trackings_on_colums"
      t.index [:customer_id], name: "index_contact_trackings_on_customer_id"
      t.index [:generation_code], name: "index_contact_trackings_on_generation_code"
      t.index [:inquiry_id], name: "index_contact_trackings_on_inquiry_id"
      t.index [:sended_at], name: "index_contact_trackings_on_sended_at"
      t.index [:sender_id, :customer_id], name: "index_contact_trackings_on_sender_id_and_customer_id"
      t.index [:sender_id, :status], name: "index_contact_trackings_on_sender_id_and_status"
      t.index [:sender_id], name: "index_contact_trackings_on_sender_id"
      t.index [:sending_started_at], name: "index_contact_trackings_on_sending_started_at"
      t.index [:session_code], name: "index_contact_trackings_on_session_code"
      t.index [:worker_id], name: "index_contact_trackings_on_worker_id"
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
      t.index [:sender_id], name: "index_inquiries_on_sender_id"
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
      t.index [:email], name: "index_senders_on_email", unique: true
      t.index [:reset_password_token], name: "index_senders_on_reset_password_token", unique: true
    end

    # Add other essential tables
    create_table :workers do |t|
      t.string :user_name, default: "", null: false
      t.string :first_name
      t.string :last_name
      t.string :tel
      t.string :email, default: "", null: false
      t.string :encrypted_password, default: "", null: false
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.string :select
      t.integer :number_code
      t.integer :deleted_customer_count, default: 0
      t.index [:email], name: "index_workers_on_email", unique: true
      t.index [:reset_password_token], name: "index_workers_on_reset_password_token", unique: true
    end

    create_table :users do |t|
      t.string :user_name, default: "", null: false
      t.string :email, default: "", null: false
      t.string :encrypted_password, default: "", null: false
      t.string :select
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [:email], name: "index_users_on_email", unique: true
      t.index [:reset_password_token], name: "index_users_on_reset_password_token", unique: true
    end
  end

  def down
    drop_table :admins
    drop_table :customers
    drop_table :contact_trackings
    drop_table :inquiries
    drop_table :senders
    drop_table :workers
    drop_table :users
  end
end