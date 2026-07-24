# YouTube HTTP 호출이 app/services/youtube 경계 밖(컨트롤러·모델·뷰·잡·헬퍼)에 새지 않음을 소스 스캔으로 가드(AD-1)
require "test_helper"

class Youtube::BoundaryTest < ActiveSupport::TestCase
  ROOT = Rails.root.to_s

  # 경계(app/services/youtube) 밖 소스 전체를 스캔한다 — app/services 형제·lib 포함.
  # app/services/embedding 은 Gemini 전용의 별개 HTTP 경계(AD-1)라 이 YouTube 가드에서 제외한다.
  def sources_outside_boundary
    (Dir.glob(File.join(ROOT, "app", "**", "*.rb")) +
     Dir.glob(File.join(ROOT, "lib", "**", "*.rb")))
      .select { |p| File.file?(p) }
      .reject { |p| p.include?("/app/services/youtube/") || p.include?("/app/services/embedding/") }
  end

  test "경계 밖에서 YouTube API에 직접 접근(HTTP·googleapis·live 어댑터)하지 않는다" do
    # 다양한 HTTP 스택(Net::HTTP·Faraday·HTTParty·RestClient·open-uri) + YouTube 엔드포인트/live 어댑터.
    forbidden = /googleapis|youtube\/v3|Youtube::Adapters::Live|Faraday|HTTParty|RestClient|open-uri|URI\.open|Net::HTTP/
    offenders = sources_outside_boundary.select do |path|
      File.read(path, encoding: "BINARY").match?(forbidden)
    end
    assert_empty offenders, "경계 밖 YouTube/HTTP 직접 참조: #{offenders.inspect}"
  end

  test "API 키는 경계 밖에서 읽지 않는다(YOUTUBE_API_KEY·Youtube::Config.api_key)" do
    forbidden = /YOUTUBE_API_KEY|Youtube::Config\.api_key/
    offenders = sources_outside_boundary.select do |path|
      File.read(path, encoding: "BINARY").match?(forbidden)
    end
    assert_empty offenders, "경계 밖 API 키 접근: #{offenders.inspect}"
  end
end
