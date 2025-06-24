class AccessLogsController < ApplicationController
  def index
    @logs = AccessLog.includes(:customer).order(created_at: :desc)
  end
end
