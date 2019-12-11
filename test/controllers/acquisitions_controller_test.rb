require 'test_helper'

class AcquisitionsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get acquisitions_show_url
    assert_response :success
  end

end
