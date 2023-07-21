# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20230507054112) do

  create_table "admins", force: :cascade do |t|
    t.string "user_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "select"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "autoform_results", force: :cascade do |t|
    t.integer "customer_id"
    t.integer "sender_id"
    t.integer "worker_id"
    t.integer "success_sent"
    t.integer "failed_sent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calls", force: :cascade do |t|
    t.string "statu"
    t.datetime "time"
    t.string "comment"
    t.integer "customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "admin_id"
    t.integer "user_id"
    t.datetime "latest_confirmed_time"
    t.index ["admin_id"], name: "index_calls_on_admin_id"
    t.index ["customer_id", "created_at"], name: "index_calls_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_calls_on_customer_id"
    t.index ["user_id", "latest_confirmed_time", "time"], name: "index_calls_on_user_id_and_latest_confirmed_time_and_time"
    t.index ["user_id"], name: "index_calls_on_user_id"
  end

  create_table "contact_trackings", force: :cascade do |t|
    t.string "code", null: false
    t.integer "customer_id", null: false
    t.integer "inquiry_id", null: false
    t.integer "sender_id"
    t.integer "worker_id"
    t.string "status", null: false
    t.string "contact_url"
    t.datetime "sended_at"
    t.datetime "callbacked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "scheduled_date"
    t.string "callback_url"
    t.string "customers_code"
    t.string "auto_job_code"
    t.index ["code"], name: "index_contact_trackings_on_code", unique: true
    t.index ["customer_id", "inquiry_id", "sender_id", "worker_id"], name: "index_contact_trackings_on_colums"
    t.index ["customer_id"], name: "index_contact_trackings_on_customer_id"
    t.index ["inquiry_id"], name: "index_contact_trackings_on_inquiry_id"
    t.index ["sender_id"], name: "index_contact_trackings_on_sender_id"
    t.index ["worker_id"], name: "index_contact_trackings_on_worker_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.string "company"
    t.string "service"
    t.string "search_1"
    t.string "target_1"
    t.string "search_2"
    t.string "target_2"
    t.string "search_3"
    t.string "target_3"
    t.string "slack_account"
    t.string "slack_id"
    t.string "slack_password"
    t.string "area"
    t.string "sales"
    t.string "calender"
    t.string "other"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "price"
    t.string "upper"
    t.string "payment"
    t.string "statu"
  end

  create_table "counts", force: :cascade do |t|
    t.string "company"
    t.string "title"
    t.string "statu"
    t.datetime "time"
    t.string "comment"
    t.integer "customer_id"
    t.integer "sender_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_counts_on_customer_id"
    t.index ["sender_id"], name: "index_counts_on_sender_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "company"
    t.string "store"
    t.string "first_name"
    t.string "last_name"
    t.string "first_kana"
    t.string "last_kana"
    t.string "tel"
    t.string "tel2"
    t.string "fax"
    t.string "mobile"
    t.string "industry"
    t.string "mail"
    t.string "url"
    t.string "people"
    t.string "postnumber"
    t.string "address"
    t.string "caption"
    t.string "remarks"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "choice"
    t.string "title"
    t.string "other"
    t.string "url_2"
    t.string "inflow"
    t.string "business"
    t.string "price"
    t.string "number"
    t.string "history"
    t.string "area"
    t.string "target"
    t.date "start"
    t.string "contact_url"
    t.string "meeting"
    t.string "experience"
    t.string "extraction_count"
    t.string "send_count"
    t.integer "worker_id"
    t.string "genre"
    t.string "forever"
    t.string "customers_code"
    t.index ["created_at"], name: "index_customers_on_created_at"
    t.index ["worker_id"], name: "index_customers_on_worker_id"
  end

  create_table "direct_mail_contact_trackings", force: :cascade do |t|
    t.string "code", null: false
    t.integer "customer_id", null: false
    t.integer "sender_id"
    t.integer "worker_id"
    t.string "status", null: false
    t.string "contact_url"
    t.datetime "sended_at"
    t.datetime "callbacked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["code"], name: "index_direct_mail_contact_trackings_on_code", unique: true
    t.index ["customer_id"], name: "index_direct_mail_contact_trackings_on_customer_id"
    t.index ["sender_id"], name: "index_direct_mail_contact_trackings_on_sender_id"
    t.index ["user_id"], name: "index_direct_mail_contact_trackings_on_user_id"
    t.index ["worker_id"], name: "index_direct_mail_contact_trackings_on_worker_id"
  end

  create_table "images", force: :cascade do |t|
    t.integer "contract_id"
    t.string "title"
    t.string "picture"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id"], name: "index_images_on_contract_id"
  end

  create_table "incentives", force: :cascade do |t|
    t.string "customer_summary_key", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.integer "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_summary_key", "year", "month"], name: "index_incentives_on_customer_summary_key_and_year_and_month"
  end

  create_table "inquiries", force: :cascade do |t|
    t.string "headline"
    t.string "from_company"
    t.string "person"
    t.string "person_kana"
    t.string "from_tel"
    t.string "from_fax"
    t.string "from_mail"
    t.string "url"
    t.string "address"
    t.string "title"
    t.string "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sender_id"
    t.index ["sender_id"], name: "index_inquiries_on_sender_id"
  end

  create_table "knowledges", force: :cascade do |t|
    t.integer "contract_id"
    t.string "question"
    t.string "genre"
    t.string "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id"], name: "index_knowledges_on_contract_id"
  end

  create_table "ng_customers", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.integer "inquiry_id", null: false
    t.integer "sender_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "admin_id"
    t.index ["admin_id"], name: "index_ng_customers_on_admin_id"
  end

  create_table "pynotifies", force: :cascade do |t|
    t.string "title"
    t.string "message"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "sended_at"
  end

  create_table "senders", force: :cascade do |t|
    t.string "user_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rate_limit"
    t.integer "default_inquiry_id"
    t.index ["email"], name: "index_senders_on_email", unique: true
    t.index ["reset_password_token"], name: "index_senders_on_reset_password_token", unique: true
  end

  create_table "smartphone_logs", force: :cascade do |t|
    t.string "token", null: false
    t.string "log_data", null: false
    t.datetime "created_at", null: false
  end

  create_table "smartphones", force: :cascade do |t|
    t.string "device_name", null: false
    t.string "token", null: false
    t.boolean "delete_flag", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "user_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "select"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workers", force: :cascade do |t|
    t.string "user_name", default: "", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "tel"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_workers_on_email", unique: true
    t.index ["reset_password_token"], name: "index_workers_on_reset_password_token", unique: true
  end

end
