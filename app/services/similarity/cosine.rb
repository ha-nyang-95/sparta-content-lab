# 두 임베딩 벡터의 완전 코사인 유사도(분모 계산) — float32 드리프트로 unit-norm 비가정(AD-10, 4.2/4.4 재사용)
module Similarity
  module Cosine
    # a·b 의 코사인 = dot(unit(a), unit(b)). nil·길이 불일치·빈 벡터·norm 0·비유한이면 nil(방어→스킵).
    # float32 드리프트로 |코사인|이 1을 미세 초과할 수 있어 [-1,1] 로 clamp 한다.
    def self.between(a, b)
      ua = unit(a)
      ub = unit(b)
      return nil if ua.nil? || ub.nil? || ua.length != ub.length

      d = dot(ua, ub)
      return nil if d.nil? || !d.finite?

      d.clamp(-1.0, 1.0)
    end

    # 단위 벡터(‖·‖=1)로 정규화. 배치는 벡터당 1회만 호출해 pair마다 norm 재계산을 없앤다.
    # nil·빈 벡터·norm 0 이면 nil.
    def self.unit(vec)
      return nil if vec.nil? || vec.empty?

      norm = Math.sqrt(vec.sum { |x| x * x })
      return nil if norm.zero?

      vec.map { |x| x / norm }
    end

    # 내적(zip 할당 없이). 길이 불일치·nil 이면 nil.
    def self.dot(a, b)
      return nil if a.nil? || b.nil? || a.length != b.length

      sum = 0.0
      i = 0
      while i < a.length
        sum += a[i] * b[i]
        i += 1
      end
      sum
    end
  end
end
