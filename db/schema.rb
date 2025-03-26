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

ActiveRecord::Schema.define(version: 20250325052644) do

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

  create_table "assignments", force: :cascade do |t|
    t.integer "crowdwork_id"
    t.integer "worker_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crowdwork_id"], name: "index_assignments_on_crowdwork_id"
    t.index ["worker_id"], name: "index_assignments_on_worker_id"
  end

  create_table "attendances", force: :cascade do |t|
    t.integer "user_id"
    t.integer "month"
    t.integer "year"
    t.float "hours_worked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_attendances_on_user_id"
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

  create_table "contacts", force: :cascade do |t|
    t.integer "worker_id"
    t.string "question"
    t.string "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["worker_id"], name: "index_contacts_on_worker_id"
  end

# Could not dump table "contracts" because of following StandardError
#   Unknown type 'jsonb' for column 'search'

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

  create_table "crowdworks", force: :cascade do |t|
    t.string "title"
    t.string "sheet"
    t.string "tab"
    t.string "area"
    t.string "business"
    t.string "genre"
    t.string "bad"
    t.string "attention"
    t.integer "worker_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["worker_id"], name: "index_crowdworks_on_worker_id"
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
    t.integer "industry_code"
    t.string "company_name"
    t.string "payment_date"
    t.string "industry_mail"
    t.integer "worker_update_count_day"
    t.integer "worker_update_count_week"
    t.integer "worker_update_count_month"
    t.integer "sender_id"
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

  create_table "email_histories", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.integer "inquiry_id", null: false
    t.datetime "sent_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_email_histories_on_customer_id"
    t.index ["inquiry_id"], name: "index_email_histories_on_inquiry_id"
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
    t.string "title"
    t.string "category"
    t.string "genre"
    t.string "file"
    t.string "file_2"
    t.string "priority"
    t.string "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_1"
    t.string "name_2"
    t.string "name_3"
    t.string "url_1"
    t.string "url_2"
    t.string "url_3"
  end

  create_table "lists", force: :cascade do |t|
    t.integer "worker_id"
    t.string "number"
    t.string "url"
    t.string "check_1"
    t.string "check_2"
    t.string "check_3"
    t.string "check_4"
    t.string "check_5"
    t.string "check_6"
    t.string "check_7"
    t.string "check_8"
    t.string "check_9"
    t.string "check_10"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["worker_id"], name: "index_lists_on_worker_id"
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

  create_table "recruits", force: :cascade do |t|
    t.string "name"
    t.string "age"
    t.string "email"
    t.string "experience"
    t.string "voice_data"
    t.string "year"
    t.string "commodity"
    t.string "hope"
    t.string "period"
    t.string "pc"
    t.string "start"
    t.text "encoded_voice_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "tel"
    t.string "agree_1"
    t.string "agree_2"
    t.string "emergency_name"
    t.string "emergency_relationship"
    t.string "emergency_tel"
    t.string "identification"
    t.string "bank"
    t.string "branch"
    t.string "bank_number"
    t.string "bank_name"
    t.string "status"
    t.text "history"
  end

  create_table "scripts", force: :cascade do |t|
    t.string "company"
    t.string "name"
    t.string "tel"
    t.string "address"
    t.string "front_talk"
    t.string "first_talk"
    t.string "introduction"
    t.string "hearing_1"
    t.string "hearing_2"
    t.string "hearing_3"
    t.string "hearing_4"
    t.string "closing"
    t.string "requirement"
    t.string "price"
    t.string "experience"
    t.string "refund"
    t.string "usp"
    t.string "other_receive_1"
    t.string "other_receive_2"
    t.string "other_receive_3"
    t.string "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "contract_id"
    t.string "title"
    t.string "requirement_title"
    t.string "price_title"
    t.string "experience_title"
    t.string "refund_title"
    t.string "usp_title"
    t.string "other_receive_1_title"
    t.string "other_receive_2_title"
    t.string "other_receive_3_title"
    t.index ["contract_id"], name: "index_scripts_on_contract_id"
  end

  create_table "sender_assignments", force: :cascade do |t|
    t.integer "worker_id", null: false
    t.integer "sender_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sender_id"], name: "index_sender_assignments_on_sender_id"
    t.index ["worker_id"], name: "index_sender_assignments_on_worker_id"
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
    t.string "url"
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

  create_table "staffs", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_staffs_on_email", unique: true
    t.index ["reset_password_token"], name: "index_staffs_on_reset_password_token", unique: true
  end

  create_table "tests", force: :cascade do |t|
    t.integer "worker_id"
    t.string "company"
    t.string "tel"
    t.string "address"
    t.string "title"
    t.string "business"
    t.string "genre"
    t.string "url"
    t.string "contact_url"
    t.string "url_2"
    t.string "store"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["worker_id"], name: "index_tests_on_worker_id"
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

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.integer "item_id", limit: 8, null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object", limit: 1073741823
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
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
    t.string "select"
    t.integer "number_code"
    t.index ["email"], name: "index_workers_on_email", unique: true
    t.index ["reset_password_token"], name: "index_workers_on_reset_password_token", unique: true
  end

  create_table "writers", force: :cascade do |t|
    t.integer "worker_id"
    t.string "title_1"
    t.string "url_1"
    t.string "title_2"
    t.string "url_2"
    t.string "title_3"
    t.string "url_3"
    t.string "title_4"
    t.string "url_4"
    t.string "title_5"
    t.string "url_5"
    t.string "title_6"
    t.string "url_6"
    t.string "title_7"
    t.string "url_7"
    t.string "title_8"
    t.string "url_8"
    t.string "title_9"
    t.string "url_9"
    t.string "title_10"
    t.string "url_10"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["worker_id"], name: "index_writers_on_worker_id"
  end

end
