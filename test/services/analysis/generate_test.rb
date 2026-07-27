# Analysis::Generate — 자막+분석 성공(ok)·무자막(unavailable)·분석기 예외 흡수(unavailable) 검증
require "test_helper"

class Analysis::GenerateTest < ActiveSupport::TestCase
  setup do
    ch = Channel.create!(name: "채널", category: "직접경쟁", source: "seed")
    @video = ch.videos.create!(youtube_video_id: "v1", title: "제목", view_count: 1)
  end

  def fake_transcript(text)
    Class.new { define_method(:call) { |_id| text } }.new
  end

  def fake_analyzer(hash)
    Class.new { define_method(:analyze) { |_text| hash } }.new
  end

  test "자막+분석 성공 시 status ok 로 저장하고 본문을 담는다" do
    analysis = Analysis::Generate.new(
      transcript: fake_transcript("스크립트 텍스트"),
      analyzer: fake_analyzer("intro_excerpt" => "도입", "intro_analysis" => "도입분석",
                              "summary" => "요약", "overall_analysis" => "전체분석")
    ).call(@video)

    assert_equal "ok", analysis.status
    assert_equal "전체분석", analysis.overall_analysis
    assert_equal analysis, @video.reload.video_analysis
  end

  test "자막을 못 가져오면 unavailable" do
    analysis = Analysis::Generate.new(transcript: fake_transcript(nil), analyzer: fake_analyzer({})).call(@video)

    assert_equal "unavailable", analysis.status
    assert analysis.detail.present?
  end

  test "분석기 예외는 unavailable 로 흡수한다(500 금지)" do
    boom = Class.new { def analyze(_text); raise "boom"; end }.new
    analysis = Analysis::Generate.new(transcript: fake_transcript("스크립트"), analyzer: boom).call(@video)

    assert_equal "unavailable", analysis.status
  end
end
