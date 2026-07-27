# 영상 기획 분석 생성 오케스트레이터 — 자막 추출 → Gemini 분석 → VideoAnalysis 물질화. 실패·무자막은 정직하게 unavailable.
module Analysis
  class Generate
    # 의존 주입(테스트가 fake 주입). 미주입 시 모드(live/stub)로 기본 선택.
    def initialize(transcript: nil, analyzer: nil)
      @transcript = transcript || default_transcript
      @analyzer = analyzer || default_analyzer
    end

    # video → VideoAnalysis(저장). 호출부(컨트롤러)가 캐시 미존재 시에만 부른다. 동시 생성 경합은 유니크로 방어.
    def call(video)
      text = @transcript.call(video.youtube_video_id)
      return unavailable(video, "자막을 가져올 수 없습니다(자막 없음 또는 원어 미상).") if text.blank?

      result = @analyzer.analyze(text)
      persist(video,
              status: "ok",
              intro_excerpt: result["intro_excerpt"],
              intro_analysis: result["intro_analysis"],
              summary: result["summary"],
              overall_analysis: result["overall_analysis"])
    rescue StandardError => e
      Rails.logger.warn("[Analysis::Generate] 실패 video##{video.id}: #{e.class}: #{e.message}")
      unavailable(video, "분석 생성에 실패했습니다. 잠시 후 다시 시도해 주세요.")
    end

    private

    def unavailable(video, detail)
      persist(video, status: "unavailable", detail: detail)
    end

    # 캐시 upsert — 동시 생성으로 유니크 경합 시 기존 행을 읽어 반환(재생성 방지).
    def persist(video, attrs)
      VideoAnalysis.create!(attrs.merge(video: video))
    rescue ActiveRecord::RecordNotUnique
      video.reload.video_analysis
    end

    def default_transcript
      Analysis::Config.mode == :stub ? StubTranscript.new : Transcript.new
    end

    def default_analyzer
      Analysis::Config.mode == :stub ? StubAnalyzer.new : Analyzer.new
    end
  end
end
