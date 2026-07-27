# Embedding::UpsertVectors 의 재생성 조건(신규·제목변경만)·idempotent·nil 방어를 spy client 로 검증
require "test_helper"

class Embedding::UpsertVectorsTest < ActiveSupport::TestCase
  # embed 호출 횟수를 세며 내부 client 에 위임하는 spy.
  class SpyClient
    attr_reader :calls

    def initialize(inner)
      @inner = inner
      @calls = 0
    end

    def embed(text)
      @calls += 1
      @inner.embed(text)
    end
  end

  setup do
    @channel = Channel.create!(name: "임베딩 채널", category: "직접경쟁", source: "seed")
    @spy = SpyClient.new(Embedding::Client.new(mode: :stub))
  end

  def make_video(title:, youtube_video_id:)
    Video.create!(channel: @channel, title: title, youtube_video_id: youtube_video_id)
  end

  # 서비스와 동일한 출처 포함 해시(mode|model|dimensions|제목).
  def expected_hash(title)
    provenance = "#{Embedding::Config.mode}|#{Embedding::Config.model}|#{Embedding::Config.dimensions}"
    Digest::SHA256.hexdigest("#{provenance}|#{title}")
  end

  test "신규 영상은 임베딩·source_hash 가 저장되고 벡터 길이가 Config.dimensions 이다" do
    video = make_video(title: "일본인을 위한 한국어", youtube_video_id: "v_new")

    Embedding::UpsertVectors.new(client: @spy).call

    video.reload
    assert video.embedding.present?
    assert_equal expected_hash("일본인을 위한 한국어"), video.embedding_source_hash
    assert_equal Embedding::Config.dimensions, video.embedding_vector.length
    assert_equal 1, @spy.calls
  end

  test "source_hash 는 출처(mode|model|dimensions)를 포함한다 — 제목만의 해시가 아니다(stub→live 전환 시 재생성)" do
    video = make_video(title: "제목", youtube_video_id: "v_prov")
    Embedding::UpsertVectors.new(client: @spy).call

    stored = video.reload.embedding_source_hash
    refute_equal Digest::SHA256.hexdigest("제목"), stored,
      "제목만의 해시면 mode/model/dimensions 변경이 감지되지 않아 가짜 stub 벡터가 잔존한다"
    assert_equal expected_hash("제목"), stored
  end

  test "공백만('   ') 제목은 스킵되고 배치를 크래시시키지 않는다(SQL where.not 이 못 거름)" do
    blank = make_video(title: "   ", youtube_video_id: "v_ws")
    kept = make_video(title: "정상 제목", youtube_video_id: "v_ok")

    assert_nothing_raised { Embedding::UpsertVectors.new(client: @spy).call }

    assert_nil blank.reload.embedding, "공백만 제목은 임베딩하지 않는다"
    assert kept.reload.embedding.present?, "정상 제목은 임베딩된다"
    assert_equal 1, @spy.calls
  end

  test "한 영상 embed 실패가 나머지 배치를 버리지 않는다(후보별 rescue)" do
    make_video(title: "실패할 제목", youtube_video_id: "v_boom")
    make_video(title: "정상 제목", youtube_video_id: "v_fine")

    boom_client = Object.new
    def boom_client.embed(text)
      raise "boom" if text == "실패할 제목"

      Embedding::Client.new(mode: :stub).embed(text)
    end

    assert_nothing_raised { Embedding::UpsertVectors.new(client: boom_client).call }

    assert_nil Video.find_by(youtube_video_id: "v_boom").embedding, "실패 영상은 스킵"
    assert Video.find_by(youtube_video_id: "v_fine").embedding.present?, "나머지는 계속 임베딩"
  end

  test "크레딧 소진(QuotaExhausted)은 삼키지 않고 즉시 전파한다(빌링 경보 신호)" do
    make_video(title: "소진 유발 제목", youtube_video_id: "v_quota")

    quota_client = Object.new
    def quota_client.embed(_text)
      raise Embedding::QuotaExhausted, "크레딧 소진"
    end

    assert_raises(Embedding::QuotaExhausted) do
      Embedding::UpsertVectors.new(client: quota_client).call
    end
  end

  test "제목이 그대로면 재실행 시 재호출하지 않는다(idempotent)" do
    make_video(title: "변경 없는 제목", youtube_video_id: "v_same")

    Embedding::UpsertVectors.new(client: @spy).call
    calls_after_first = @spy.calls
    assert_equal 1, calls_after_first

    Embedding::UpsertVectors.new(client: @spy).call
    assert_equal calls_after_first, @spy.calls, "변경 없는 제목은 재호출되면 안 된다"
  end

  test "제목이 바뀌면 재호출되고 source_hash 가 갱신된다" do
    video = make_video(title: "원래 제목", youtube_video_id: "v_change")
    Embedding::UpsertVectors.new(client: @spy).call
    old_hash = video.reload.embedding_source_hash
    assert_equal 1, @spy.calls

    video.update!(title: "바뀐 제목")
    Embedding::UpsertVectors.new(client: @spy).call

    video.reload
    assert_equal 2, @spy.calls
    refute_equal old_hash, video.embedding_source_hash
    assert_equal expected_hash("바뀐 제목"), video.embedding_source_hash
  end

  test "nil·빈 제목 영상은 스킵되고 embedding 이 nil 로 남는다(예외 없음)" do
    nil_video = make_video(title: nil, youtube_video_id: "v_nil")
    blank_video = make_video(title: "", youtube_video_id: "v_blank")

    assert_nothing_raised { Embedding::UpsertVectors.new(client: @spy).call }

    assert_nil nil_video.reload.embedding
    assert_nil blank_video.reload.embedding
    assert_equal 0, @spy.calls
  end

  test "전부 해시 일치인 재실행은 embed 호출이 0 이다" do
    make_video(title: "제목 하나", youtube_video_id: "v_a")
    make_video(title: "제목 둘", youtube_video_id: "v_b")

    Embedding::UpsertVectors.new(client: @spy).call
    assert_equal 2, @spy.calls

    second_spy = SpyClient.new(Embedding::Client.new(mode: :stub))
    Embedding::UpsertVectors.new(client: second_spy).call
    assert_equal 0, second_spy.calls
  end
end
