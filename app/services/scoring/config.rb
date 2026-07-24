# config/scoring.yml(AD-4 튜닝값 단일 소재지)을 1회 로드·memoize 하는 얇은 로더
module Scoring
  module Config
    PATH = Rails.root.join("config", "scoring.yml")

    class << self
      # 전체 설정을 deep-symbolize + deep-freeze 해서 반환(1회 로드 후 memoize).
      # 동결로 단일 원천이 다운스트림(Epic 3 소비자)에서 변형되는 것을 막는다.
      def all
        @all ||= deep_freeze((YAML.safe_load_file(PATH) || {}).deep_symbolize_keys)
      end

      # 중첩 키 조회. 예: fetch(:performance, :extreme_multiple) => 25
      # 경로 중 하나라도 없으면 KeyError(하드코딩·오타 회귀를 테스트가 포착).
      def fetch(*keys)
        raise ArgumentError, "fetch 는 키가 최소 1개 필요하다" if keys.empty?

        keys.reduce(all) do |node, key|
          unless node.is_a?(Hash) && node.key?(key)
            raise KeyError, "scoring.yml 키 경로 없음: #{keys.inspect} (#{key} 에서 실패)"
          end
          node.fetch(key)
        end
      end

      private

      def deep_freeze(obj)
        case obj
        when Hash  then obj.each_value { |v| deep_freeze(v) }.freeze
        when Array then obj.each { |v| deep_freeze(v) }.freeze
        else            obj.freeze
        end
      end
    end
  end
end
