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

ActiveRecord::Schema.define(version: 20220118075432) do

  create_table "admins", force: :cascade do |t|
    t.string "user_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "select"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "calls", force: :cascade do |t|
    t.string "statu"
    t.datetime "time"
    t.string "comment"
    t.integer "customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "admin_id"
    t.integer "crm_id"
    t.integer "user_id"
    t.datetime "latest_confirmed_time"
    t.index ["admin_id"], name: "index_calls_on_admin_id"
    t.index ["crm_id"], name: "index_calls_on_crm_id"
    t.index ["customer_id", "created_at"], name: "index_calls_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_calls_on_customer_id"
    t.index ["user_id", "latest_confirmed_time", "time"], name: "index_calls_on_user_id_and_latest_confirmed_time_and_time"
    t.index ["user_id"], name: "index_calls_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_clients_on_email", unique: true
    t.index ["reset_password_token"], name: "index_clients_on_reset_password_token", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.integer "crm_id"
    t.string "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crm_id"], name: "index_comments_on_crm_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "company"
    t.string "name"
    t.string "tel"
    t.string "address"
    t.string "email"
    t.string "subject"
    t.string "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "crms", force: :cascade do |t|
    t.string "company"
    t.string "first_name"
    t.string "last_name"
    t.string "first_kana"
    t.string "last_kana"
    t.string "tel"
    t.string "mobile"
    t.string "fax"
    t.string "mail"
    t.string "postnumber"
    t.string "prefecture"
    t.string "city"
    t.string "town"
    t.string "building"
    t.string "item"
    t.string "statu"
    t.string "price"
    t.string "number"
    t.string "history"
    t.string "area"
    t.string "target"
    t.string "next"
    t.string "content"
    t.string "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "date_time"
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
    t.string "memo_5"
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
    t.string "choice"
    t.string "sfa_statu"
    t.string "contact_url"
    t.string "meeting"
    t.string "experience"
    t.string "extraction_count"
    t.string "send_count"
    t.integer "worker_id"
    t.index ["created_at"], name: "index_customers_on_created_at"
    t.index ["worker_id"], name: "index_customers_on_worker_id"
  end

  create_table "customers_search_orders", force: :cascade do |t|
    t.integer "admin_id"
    t.integer "customer_id"
    t.integer "prev_customer_id"
    t.integer "next_customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "estimates", force: :cascade do |t|
    t.integer "customer_id"
    t.string "title"
    t.string "status"
    t.string "deadline"
    t.string "payment"
    t.string "subject"
    t.string "item1"
    t.string "item2"
    t.string "item3"
    t.string "item4"
    t.string "item5"
    t.string "price1"
    t.string "price2"
    t.string "price3"
    t.string "price4"
    t.string "price5"
    t.string "quantity1"
    t.string "quantity2"
    t.string "quantity3"
    t.string "quantity4"
    t.string "quantity5"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_estimates_on_customer_id"
  end

  create_table "images", force: :cascade do |t|
    t.integer "crm_id"
    t.string "name"
    t.string "views"
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crm_id"], name: "index_images_on_crm_id"
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
  end

  create_table "matters", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "possible"
    t.string "impossible"
    t.string "information"
    t.string "attention"
    t.integer "admin_id"
    t.integer "member_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_matters_on_admin_id"
    t.index ["member_id"], name: "index_matters_on_member_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.string "file"
    t.string "choice"
    t.string "keyword"
    t.string "description"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "senders", force: :cascade do |t|
    t.string "user_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "select"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_senders_on_email", unique: true
    t.index ["reset_password_token"], name: "index_senders_on_reset_password_token", unique: true
  end

  create_table "skillsheets", force: :cascade do |t|
    t.string "name"
    t.string "tel"
    t.string "mail"
    t.string "address"
    t.string "age"
    t.string "start"
    t.string "experience"
    t.string "history"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "upload_data", force: :cascade do |t|
    t.string "name"
    t.string "file"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_upload_data_on_company_id"
  end

  create_table "upload_files", force: :cascade do |t|
    t.string "name"
    t.string "file"
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
