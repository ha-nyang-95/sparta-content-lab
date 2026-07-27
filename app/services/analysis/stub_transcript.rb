# 테스트/stub 모드용 자막 추출 — 실 yt-dlp 호출 없이 결정적 더미 자막 반환(제목 빈 영상은 nil=무자막 경로).
module Analysis
  class StubTranscript
    def call(_youtube_video_id)
      "안녕하세요. 오늘은 스텁 자막입니다. 이 영상은 테스트용 결정적 스크립트로 도입부와 본문을 담고 있습니다."
    end
  end
end
