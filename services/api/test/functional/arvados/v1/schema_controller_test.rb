require 'test_helper'

class Arvados::V1::SchemaControllerTest < ActionController::TestCase

  test "should get fresh discovery document" do
    MAX_SCHEMA_AGE = 60
    get :discovery_rest_description
    assert_response :success
    discovery_doc = JSON.parse(@response.body)
    assert_equal 'discovery#restDescription', discovery_doc['kind']
    assert_equal(true,
                 Time.now - MAX_SCHEMA_AGE.seconds < discovery_doc['generatedAt'],
                 "discovery document was generated >#{MAX_SCHEMA_AGE}s ago")
  end

end
