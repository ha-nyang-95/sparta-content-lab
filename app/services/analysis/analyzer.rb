# 자막(스크립트) → Gemini 텍스트 분석. 확정 형식(도입부 발췌·도입부 분석·전체 요약·전체 분석)을 JSON 으로 받는다.
require "net/http"
require "uri"
require "json"

module Analysis
  class Analyzer
    class Error < StandardError; end

    BASE_URL = "https://generativelanguage.googleapis.com/v1beta".freeze

    def initialize(api_key: Analysis::Config.api_key, model: Analysis::Config.model)
      @api_key = api_key
      @model = model
    end

    # transcript(String) → { "intro_excerpt", "intro_analysis", "summary", "overall_analysis" }.
    def analyze(transcript)
      raise Error, "GEMINI_API_KEY 없음 — 분석 호출 불가" if @api_key.blank?

      uri = URI("#{BASE_URL}/models/#{@model}:generateContent")
      uri.query = URI.encode_www_form(key: @api_key)

      body = {
        contents: [{ parts: [{ text: prompt(transcript) }] }],
        generationConfig: { responseMimeType: "application/json", temperature: 0.4 }
      }
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body)

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 120) { |h| h.request(req) }
      raise Error, "HTTP #{res.code}: #{res.body.to_s[0, 200]}" unless res.is_a?(Net::HTTPSuccess)

      text = JSON.parse(res.body).dig("candidates", 0, "content", "parts", 0, "text")
      raise Error, "빈 응답" if text.blank?

      JSON.parse(text)
    end

    private

    # 확정 형식 — 3번째 '잘한 점' 섹션은 overall_analysis 에 녹였다(중복 제거·전 영상 통일).
    def prompt(transcript)
      <<~PROMPT
        다음은 유튜브 영상의 자막(스크립트)입니다. 콘텐츠 기획자 관점에서 이 영상을 분석하세요.
        반드시 아래 키만 가진 JSON 하나만 출력하세요(모든 값은 한국어):
        - intro_excerpt: 도입부(첫 부분) 스크립트를 원문 그대로 2~4문장 발췌
        - intro_analysis: 도입부 기획 분석 — 어떻게 시청자를 붙잡는가(후킹 전략)
        - summary: 전체 스크립트 요약 3~5문장
        - overall_analysis: 전체 기획 분석 — 구성·흐름·타깃·전략, 그리고 이 영상이 특별히 잘한 점을 함께 서술

        자막:
        #{transcript}
      PROMPT
    end
  end
end
