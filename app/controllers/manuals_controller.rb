class ManualsController < ApplicationController
  before_action :authenticate_admin!, only: [:officework]
  before_action :authenticate_user!, only: [:index]

  def index
  end

  def officework
  end

end
