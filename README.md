# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
# smart
# smart

------

## (1)(2)の制作
### Staff

create staff model for [弊社管理者] role

```command
rails g devise Staff
```

create views set for staff model

```command
rails g devise:views staffs
```

and also change config/initializers/devise.rb

```ruby
config.scoped_views = true
```

set redirector like the following in ApplicationController(app/controllers/application_controller.rb) as well

- User
- Staff

2点のdevise利用したモデルが存在するので、以下の通りに追加しております

* after_sign_in_path_for

  User（ユーザー）やStaff（「弊社管理者」）がログインした後にどの画面に遷移するかを記載

* after_sign_out_path_for

  User（ユーザー）やStaff（「弊社管理者」）がログアウトした後にどの画面に遷移するかを記載

```ruby
private
  # set for devise login redirector
  def after_sign_in_path_for(resource)
    case resource
    when User
      # put here for User first page direct path after signed in
      # your_home_path
    when Staff
    else
      super
    end
  end

  def after_sign_out_path_for(resource)
    case resource
    when User, :user, :users
      new_user_session_path
      # put here for User default page direct path after signed out
    when Staff, :staff, :staffs
      new_staff_session_path
      # put here for Staff default page direct path after signed out
    else
      super
    end
  end
```

#### User のログイン関連のviews

app/views/devise -> app/views/users
<br/>
にディレクトリを変更しております

#### Staff のログイン関連のviews

app/views/staffs/ 直下に一式設置<br/>
このディレクトリのファイルを編集することで
Staff用の画面内容を変更できます

app/views/layouts/staffs.html.erb
<br/>
「弊社管理画面」レイアウトがユーザー画面とレイアウトが違う場合は上記をご利用くださいませ。

#### devise関連の画面項目名
* config/locales/devise.ja.yml

上記を編集いただくことで日本語化することができます。

合わせて、以下のファイルも日本語エラーメッセージを表示するのに必要ですので追加しております。
* config/locales/ja.yml

## (3)の制作
### User

User モデルのログインセッションチェック及び、ログイン中にのみ、出勤・退勤のボタン押下できるようにするため
MainController (app/controllers/main_controller.rb) を追加
このコントローラーを継承することでログイン中のいかなる処理も必ずログインセッションのチェックをすることが可能になる

### Attend

出勤／退勤の登録

```teminal
rails g scaffold attend user:belongs_to
```

app/views/home/index.html.erb
<br/>
出勤・退勤のボタン押下のサンプル処理を追加

app/controllers/attends_controller.rb
<br/>
start：出勤ボタン押下した際の登録処理
<br/>
finish：退勤ボタン押下した際の登録処理

```ruby
  def start
    ...
  end

  def finish
    ...
  end
```

## (4)の制作
### 帳票

Use Thinreports<br/>
http://www.thinreports.org/

Gemfile
```ruby
gem 'thinreports'
```

config/application.rb

```ruby
# Thinreports
config.autoload_paths += %W(#{config.root}/app/reports)
```

app/reports ディレクトリを追加<br/>
帳票系のレイアウトファイルを保持するディレクトリ<br/>
application.rb に追加した行はこのディレクトリにパスを通す意味合い

sample

```
app/reports/layouts/salary.tlf
```

app/controllers/workers_controller.rb

```ruby
# 帳票出力処理
def print
  ...
  # (処理内容は実際のcontrollerを参照ください)
  ...
end
```

## (5)の制作
### db/migrateの編集
#### 編集したテーブル
* rurles：managementsテーブル、usersテーブルのリレーションを追加、整数型・日付型のカラムを修正
* users：managementsテーブル、workersテーブルのリレーションを追加

#### 追加したテーブル
* staffs：「弊社管理」ログイン用の従業員モデル・テーブル
* attends：出席・退勤を保存するモデル・テーブル


# 2018.05.18 [1]
- - -
## (2)新規作成画面

新規作成用のdeviseのコントローラーをカスタマイズ

```terminal
rails g devise:controllers users -c=registrations
```

app/controllers/users/registrations_controller.rb の以下のメソッドを編集

```ruby
# GET /resource/sign_up
def new
  # 実際のcontrollerの内容を参照ください
end

# POST /resource
def create
  # 実際のcontrollerの内容を参照ください
end
```

app/views/users/registrations/new.html.erb に追記

```html
<div class="field">
  <%= label :management, :company %><br />
  <%= text_field :management, :company %>
</div>
<div class="field">
  <%= label :management, :company_short %><br />
  <%= text_field :management, :company_short %>
</div>
<%# 上記と同様にしてmanagementsテーブルで必要な項目を追加していってください %>

<div class="field">
  <%= label :rule, :trial_period_start_on %><br />
  <%= date_field :rule, :trial_period_start_on %>
</div>
<div class="field">
  <%= label :rule, :trial_period_end_on %><br />
  <%= date_field :rule, :trial_period_end_on %>
</div>
<%# 上記と同様にしてrulesテーブルで必要な項目を追加していってください %>
```

routes.rb に以下を追記
```ruby
devise_for :users, controllers: {
  registrations: 'users/registrations'
}
```

## (4)出勤簿・賃金台帳への反映

app/controllers/attends_controller.rb の #printメソッドを参照くださいませ

データの取得方法を記載しております

これを元に画面を作成いただければと思います

このメソッドは給与明細印刷に利用しているメソッドです

出力しているデータは出勤・退勤ボタンを押下した際に取得したデータをそのまま表示しております

- - -

# 2018.05.22 [1]

## Staffレイアウト

app/controllers/application_controller.rb に以下を追記

```ruby
layout :layout_by_resource

...
private
...
  # Layout per resource_name
  def layout_by_resource
    if devise_controller? && resource_name == :staff
      "staffs"
    else
      "application"
    end
  end
```

app/views/layouts/staffs.html.erb を編集

「ログイン」→「ログイン(staff)」

```html
<% if staff_signed_in? %>
<!-- current_user は現在ログインしているUserオブジェクトを返すdeviseのHelperメソッド -->
<!-- *_path はUserモデルを作成したときに、deviseにより自動で作成されてますので、rake routesで確認できます -->
        <strong><% current_user.email  %></strong>
            <%= link_to "ログアウト", destroy_staff_session_path, method: :delete %>
<% else %>
            <%= link_to "ログイン(staff)", new_staff_session_path%>
 <% end %>
```

* users でアクセス

  /users/sign_in

  ヘッダーメニュー「ログイン」になっている

* staffs でアクセス

  /staffs/sign_in

  ヘッダーメニュー「ログイン(staff)」になっている

それぞれでアクセスして確認くださいませ。

- - -
# 2018.05.28 [1]
## bugfix : homeの「テストプリント」ボタン押下を修正

app/views/home/index.html.erb

```html
<%- if @current_attend.present? -%>

を以下に修正

<%- if current_user.present? && current_user.attends.exists? -%>
```

app/controllers/workers_controller.rb

  end_atがnilの場合、exception発生を修正しました。

```ruby
work_time: "#{I18n.l(item.start_at, format: :xs)}-#{I18n.l(item.end_at, format: :xs)}",

を以下に修正

_start_at = item.start_at.present? ? I18n.l(item.start_at, format: :xs) : nil
_end_at   = item.end_at.present? ? I18n.l(item.end_at, format: :xs) : nil
...
work_time: "#{_start_at}-#{_end_at}",
...
```
