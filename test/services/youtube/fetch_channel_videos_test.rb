# FetchChannelVideos — 스텁 열거로 Video 생성·is_short 판정/불변·nil 방어·재수집 upsert·handle-only 스킵 검증
require "test_helper"

class Youtube::FetchChannelVideosTest < ActiveSupport::TestCase
  def make_channel(youtube_channel_id: "UCtest")
    Channel.create!(name: "t", category: "직접경쟁", source: "seed", youtube_channel_id: youtube_channel_id)
  end

  test "스텁 체인으로 3개 Video 를 생성하고 is_short/nil 방어/duration 을 저장한다" do
    channel = make_channel
    count = Youtube::FetchChannelVideos.new.call(channel)

    assert_equal 3, count
    assert_equal 3, channel.videos.count

    v1 = channel.videos.find_by(youtube_video_id: "vid_stub_0001")
    v2 = channel.videos.find_by(youtube_video_id: "vid_stub_0002")
    v3 = channel.videos.find_by(youtube_video_id: "vid_stub_0003")

    # is_short: 253s→false, 58s→true, 724s→false
    assert_equal false, v1.is_short
    assert_equal true, v2.is_short
    assert_equal false, v3.is_short

    # duration 은 초 정수로 저장
    assert_equal 253, v1.duration
    assert_equal 58, v2.duration
    assert_equal 724, v3.duration

    # nil 방어: 0002 like/comment 누락, 0003 viewCount 누락(회원전용)
    assert_nil v2.like_count
    assert_nil v2.comment_count
    assert_nil v3.view_count
    assert_equal 8890, v2.view_count
  end

  test "채널 uploads_playlist_id·subscriber_count 를 channels.list 응답으로 갱신한다" do
    channel = make_channel
    Youtube::FetchChannelVideos.new.call(channel)
    channel.reload

    assert_equal "UU_stub_trilingual_tomi", channel.uploads_playlist_id
    assert_equal 210_000, channel.subscriber_count
  end

  test "is_short 는 단일 writer 로 불변 — 잘못 설정된 값을 재분류하지 않고 view_count 는 갱신된다" do
    channel = make_channel
    # 0002(58s)는 원래 short(true)여야 하지만 일부러 false 로 선-생성한다.
    channel.videos.create!(youtube_video_id: "vid_stub_0002", is_short: false, view_count: 1)

    Youtube::FetchChannelVideos.new.call(channel)

    v2 = channel.videos.find_by(youtube_video_id: "vid_stub_0002")
    # 재분류되지 않고 false 유지(단일 writer 불변)
    assert_equal false, v2.is_short
    # 통계는 갱신
    assert_equal 8890, v2.view_count
    # 중복 생성 없음
    assert_equal 3, channel.videos.count
  end

  test "재수집해도 중복 행이 생기지 않고 view_count 는 갱신된다" do
    channel = make_channel
    Youtube::FetchChannelVideos.new.call(channel)
    channel.videos.find_by(youtube_video_id: "vid_stub_0001").update!(view_count: 1)

    Youtube::FetchChannelVideos.new.call(channel)

    assert_equal 3, channel.videos.count
    assert_equal 1234, channel.videos.find_by(youtube_video_id: "vid_stub_0001").view_count
  end

  test "handle-only 채널(youtube_channel_id nil)은 스킵하고 영상을 만들지 않는다" do
    channel = Channel.create!(name: "handle-only", category: "직접경쟁", source: "seed", handle: "@h")
    assert_nil channel.youtube_channel_id

    count = Youtube::FetchChannelVideos.new.call(channel)

    assert_equal 0, count
    assert_equal 0, channel.videos.count
  end

  # 스텁은 채널마다 같은 vid id 를 준다 — 전역 유니크 인덱스와 채널-스코프 upsert 가 충돌하면
  # 2번째 채널 수집이 크래시한다(2.5 다채널 수집 모드). 전역 upsert 로 안 깨지는지 검증.
  test "여러 채널을 연속 수집해도(같은 stub id) 크래시하지 않는다" do
    ch_a = make_channel(youtube_channel_id: "UCaaa")
    ch_b = make_channel(youtube_channel_id: "UCbbb")

    assert_nothing_raised do
      Youtube::FetchChannelVideos.new.call(ch_a)
      Youtube::FetchChannelVideos.new.call(ch_b)
    end
    # 전역 유니크라 총 3행(스텁 id 공유 — 실데이터는 채널 전속이라 이동 없음).
    assert_equal 3, Video.count
  end

  # --- 주입 fake client 로 실데이터 엣지 검증 ---
  class FakeClient
    def initialize(channel_item:, video_items: [], playlist_ids: [])
      @channel_item = channel_item
      @video_items = video_items
      @playlist_ids = playlist_ids
    end

    def list_channels(_ids) = [@channel_item].compact

    def each_playlist_item(_uploads)
      return enum_for(:each_playlist_item, _uploads) unless block_given?

      @playlist_ids.each { |id| yield({ "contentDetails" => { "videoId" => id } }) }
    end

    def list_videos(_ids) = @video_items
  end

  test "P0D(라이브/프리미어, duration 0)은 is_short 를 분류하지 않고 미룬다" do
    channel = make_channel
    item = { "id" => "vid_live", "snippet" => { "title" => "라이브" },
             "contentDetails" => { "duration" => "P0D" }, "statistics" => { "viewCount" => "5" } }
    client = FakeClient.new(
      channel_item: { "id" => channel.youtube_channel_id,
                      "contentDetails" => { "relatedPlaylists" => { "uploads" => "UU_live" } },
                      "statistics" => { "subscriberCount" => "10" } },
      video_items: [item], playlist_ids: ["vid_live"]
    )
    Youtube::FetchChannelVideos.new(client: client).call(channel)

    v = channel.videos.find_by(youtube_video_id: "vid_live")
    assert_equal 0, v.duration
    assert_nil v.is_short, "P0D 는 미분류(nil)로 남아야 한다"
  end

  test "channels.list 응답에 subscriberCount 가 없으면 기존 값을 nil 로 덮지 않는다" do
    channel = make_channel
    channel.update!(subscriber_count: 12_345, uploads_playlist_id: "UU_existing")
    client = FakeClient.new(
      channel_item: { "id" => channel.youtube_channel_id,
                      "contentDetails" => { "relatedPlaylists" => { "uploads" => "UU_existing" } },
                      "statistics" => {} }, # subscriberCount 숨김(hiddenSubscriberCount)
      video_items: [], playlist_ids: []
    )
    Youtube::FetchChannelVideos.new(client: client).call(channel)

    assert_equal 12_345, channel.reload.subscriber_count, "숨긴 구독자수가 nil 로 덮이면 안 된다"
  end

  test "수집 도중 실패하면 채널 갱신도 롤백된다(채널별 원자성)" do
    channel = make_channel
    channel.update!(subscriber_count: 100)
    raising = Class.new(FakeClient) { def list_videos(_ids) = raise("boom") }.new(
      channel_item: { "id" => channel.youtube_channel_id,
                      "contentDetails" => { "relatedPlaylists" => { "uploads" => "UU_x" } },
                      "statistics" => { "subscriberCount" => "999" } },
      playlist_ids: ["vid_x"]
    )
    assert_raises(RuntimeError) { Youtube::FetchChannelVideos.new(client: raising).call(channel) }

    assert_equal 100, channel.reload.subscriber_count, "실패 시 채널 갱신이 롤백돼야 한다"
  end
end
