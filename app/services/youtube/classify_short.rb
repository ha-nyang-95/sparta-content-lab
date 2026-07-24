# duration(초) 휴리스틱으로 is_short 를 판정 — 임계는 scoring.yml, nil→nil(미분류)
module Youtube
  module ClassifyShort
    # seconds nil 이면 nil(미분류), 아니면 임계 이하일 때 true(쇼츠).
    def self.short?(duration_seconds)
      return nil if duration_seconds.nil?

      duration_seconds <= Scoring::Config.fetch(:is_short, :max_duration_seconds)
    end
  end
end
