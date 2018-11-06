class Contact
  include ActiveModel::Model

  attr_accessor :name, :email, :message

  validates :name, :presence => {:message => '名前を入力してください'}
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, format: { with: VALID_EMAIL_REGEX ,:message => 'メールアドレスを入力してください'}
end