require 'test_helper'

class UploaderControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get uploader_index_url
    assert_response :success
  end

  test "should get form" do
    get uploader_form_url
    assert_response :success
  end

  test "should get upload" do
    get uploader_upload_url
    assert_response :success
  end

  test "should get download" do
    get uploader_download_url
    assert_response :success
  end

end
