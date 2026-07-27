# 테스트/stub 모드용 분석기 — 실 Gemini 호출 없이 확정 형식의 결정적 더미 분석 반환.
module Analysis
  class StubAnalyzer
    def analyze(transcript)
      {
        "intro_excerpt" => transcript.to_s[0, 40],
        "intro_analysis" => "[stub] 도입부 후킹 분석",
        "summary" => "[stub] 전체 스크립트 요약",
        "overall_analysis" => "[stub] 전체 기획 분석 및 잘한 점"
      }
    end
  end
end
