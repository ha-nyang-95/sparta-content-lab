# Youtube::Config 의 모드 분기(기본 stub)와 키 읽기 위치를 검증
require "test_helper"

class Youtube::ConfigTest < ActiveSupport::TestCase
  test "mode 는 기본 :stub 이다" do
    with_env("YOUTUBE_API_MODE" => nil) do
      assert_equal :stub, Youtube::Config.mode
    end
  end

  test "YOUTUBE_API_MODE=live 이면 :live" do
    with_env("YOUTUBE_API_MODE" => "live") do
      assert_equal :live, Youtube::Config.mode
    end
  end

  test "알 수 없는 모드 값은 :stub 로 폴백" do
    with_env("YOUTUBE_API_MODE" => "banana") do
      assert_equal :stub, Youtube::Config.mode
    end
  end

  test "api_key 는 ENV YOUTUBE_API_KEY 에서 읽는다" do
    with_env("YOUTUBE_API_KEY" => "test-key-from-env") do
      assert_equal "test-key-from-env", Youtube::Config.api_key
    end
  end

  private

  def with_env(overrides)
    saved = overrides.keys.index_with { |k| ENV[k] }
    overrides.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
