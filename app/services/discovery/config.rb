# config/discovery.yml(발굴 키워드 시드 단일 소재지)을 1회 로드·memoize 하는 얇은 로더
module Discovery
  module Config
    PATH = Rails.root.join("config", "discovery.yml")

    class << self
      # 전체 설정을 deep-symbolize + deep-freeze 해서 반환(1회 로드 후 memoize).
      def all
        @all ||= deep_freeze((YAML.safe_load_file(PATH) || {}).deep_symbolize_keys)
      end

      # { "직접경쟁" => [...], ... } — category 는 Channel.category 와 정합하도록 문자열 키로 반환.
      # 알 수 없는 category 키는 config 로드 시점에 fail-fast 시킨다(create! 에서 RecordInvalid 폭발 방지).
      def keywords_by_category
        kw = fetch(:keywords).transform_keys(&:to_s)
        invalid = kw.keys - Channel::CATEGORIES
        if invalid.any?
          raise KeyError, "discovery.yml 알 수 없는 category: #{invalid.inspect} (허용: #{Channel::CATEGORIES.inspect})"
        end
        kw
      end

      # 중첩 키 조회. 경로 중 하나라도 없으면 KeyError(하드코딩·오타 회귀를 테스트가 포착).
      def fetch(*keys)
        raise ArgumentError, "fetch 는 키가 최소 1개 필요하다" if keys.empty?

        keys.reduce(all) do |node, key|
          unless node.is_a?(Hash) && node.key?(key)
            raise KeyError, "discovery.yml 키 경로 없음: #{keys.inspect} (#{key} 에서 실패)"
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
