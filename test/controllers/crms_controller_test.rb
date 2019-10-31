require 'test_helper'

class CrmsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get crms_index_url
    assert_response :success
  end

end
