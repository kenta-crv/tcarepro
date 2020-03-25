require 'test_helper'

class AdminsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get admins_show_url
    assert_response :success
  end

end
