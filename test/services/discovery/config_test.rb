# Discovery::Config 로더가 4분류 키워드 그룹을 노출하고 단일 소재지에서만 읽음을 검증
require "test_helper"

class Discovery::ConfigTest < ActiveSupport::TestCase
  test "keywords_by_category 는 Channel::CATEGORIES 부분집합의 문자열 키·비어있지 않은 문자열 배열을 반환한다" do
    kbc = Discovery::Config.keywords_by_category
    assert_instance_of Hash, kbc
    assert kbc.keys.all? { |k| k.is_a?(String) }, "category 키는 문자열이어야 한다"
    assert kbc.keys.all? { |k| Channel::CATEGORIES.include?(k) }, "키는 4분류 안에 있어야 한다"

    kbc.each_value do |keywords|
      assert_instance_of Array, keywords
      assert keywords.any?, "각 분류는 최소 1개 키워드를 가진다"
      assert keywords.all? { |kw| kw.is_a?(String) && kw.present? }, "키워드는 non-empty 문자열"
    end
  end

  test "로더는 config/discovery.yml 단일 소재지에서만 읽는다" do
    raw = YAML.load_file(Rails.root.join("config/discovery.yml"))
    assert_equal raw["keywords"], Discovery::Config.keywords_by_category
  end

  test "없는 키 fetch 는 KeyError 를 raise 한다" do
    assert_raises(KeyError) { Discovery::Config.fetch(:no_such_group) }
  end

  test "알 수 없는 category 키는 로드 시 KeyError 로 fail-fast 한다" do
    # keywords_by_category 는 Channel::CATEGORIES 로 키를 검증한다. 잘못된 키를 임시 주입해 확인.
    orig = Discovery::Config.instance_variable_get(:@all)
    Discovery::Config.instance_variable_set(:@all, { keywords: { "없는분류": ["x"] } })
    assert_raises(KeyError) { Discovery::Config.keywords_by_category }
  ensure
    Discovery::Config.instance_variable_set(:@all, orig)
  end

end
