# Gemini 임베딩 HTTP·키가 app/services/embedding 경계 밖(컨트롤러·모델·뷰·잡·헬퍼)에 새지 않음을 소스 스캔으로 가드(AD-1)
require "test_helper"

class Embedding::BoundaryTest < ActiveSupport::TestCase
  ROOT = Rails.root.to_s

  # 경계(app/services/embedding) 밖 소스 전체를 스캔한다 — app/services 형제·lib 포함.
  # app/services/youtube 는 별개의 sanctioned HTTP 경계(YouTube 전용)라 이 Gemini 가드에서 제외한다.
  def sources_outside_boundary
    (Dir.glob(File.join(ROOT, "app", "**", "*.rb")) +
     Dir.glob(File.join(ROOT, "lib", "**", "*.rb")))
      .select { |p| File.file?(p) }
      .reject { |p| p.include?("/app/services/embedding/") || p.include?("/app/services/youtube/") }
  end

  test "경계 밖에서 Gemini 임베딩 API에 직접 접근(HTTP·googleapis·live 어댑터)하지 않는다" do
    forbidden = /generativelanguage|embedContent|Embedding::Adapters::Live|Faraday|HTTParty|RestClient|open-uri|URI\.open|Net::HTTP/
    offenders = sources_outside_boundary.select do |path|
      File.read(path, encoding: "BINARY").match?(forbidden)
    end
    assert_empty offenders, "경계 밖 Gemini/HTTP 직접 참조: #{offenders.inspect}"
  end

  test "Gemini 키는 경계 밖에서 읽지 않는다(GEMINI_API_KEY·Embedding::Config.api_key)" do
    forbidden = /GEMINI_API_KEY|Embedding::Config\.api_key/
    offenders = sources_outside_boundary.select do |path|
      File.read(path, encoding: "BINARY").match?(forbidden)
    end
    assert_empty offenders, "경계 밖 Gemini 키 접근: #{offenders.inspect}"
  end
end
