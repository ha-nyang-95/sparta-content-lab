# Embedding::Config 의 모드 분기(기본 stub)·모델 기본·차원을 검증
require "test_helper"

class Embedding::ConfigTest < ActiveSupport::TestCase
  test "mode 는 기본 :stub 이다" do
    with_env("EMBEDDING_MODE" => nil) do
      assert_equal :stub, Embedding::Config.mode
    end
  end

  test "EMBEDDING_MODE=live 이면 :live" do
    with_env("EMBEDDING_MODE" => "live") do
      assert_equal :live, Embedding::Config.mode
    end
  end

  test "알 수 없는 모드 값은 :stub 로 폴백" do
    with_env("EMBEDDING_MODE" => "banana") do
      assert_equal :stub, Embedding::Config.mode
    end
  end

  test "model 은 기본 gemini-embedding-001 이다" do
    with_env("GEMINI_EMBEDDING_MODEL" => nil) do
      assert_equal "gemini-embedding-001", Embedding::Config.model
    end
  end

  test "model 은 GEMINI_EMBEDDING_MODEL 로 오버라이드된다" do
    with_env("GEMINI_EMBEDDING_MODEL" => "custom-model") do
      assert_equal "custom-model", Embedding::Config.model
    end
  end

  test "dimensions 는 기본 768 이다" do
    with_env("GEMINI_EMBEDDING_DIMENSIONS" => nil) do
      assert_equal 768, Embedding::Config.dimensions
    end
  end

  test "api_key 는 ENV GEMINI_API_KEY 에서 읽는다" do
    with_env("GEMINI_API_KEY" => "test-key-from-env") do
      assert_equal "test-key-from-env", Embedding::Config.api_key
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
