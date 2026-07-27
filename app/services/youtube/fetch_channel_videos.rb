# 채널별 uploads 재생목록을 2.2 경계로 열거해 Video 로 upsert — is_short 는 최초 1회만 판정(AD-8)
module Youtube
  class FetchChannelVideos
    def initialize(client: Youtube::Client.new)
      @client = client
    end

    # channels.list→playlistItems.list→videos.list 체인으로 Video 물질화. 수집한 영상 수 반환.
    # 채널별로 트랜잭션 — 한 채널의 물질화는 all-or-nothing(부분 저장 방지, 앞 채널은 보존).
    # limit: 최근 N개만 수집(uploads 재생목록은 최신순 → lazy 페이지네이션이 일찍 멈춰 쿼터 절약). nil=전체.
    def call(channel, limit: nil)
      if channel.youtube_channel_id.blank?
        Rails.logger.info("[Youtube] handle-only 채널 스킵(채널ID 미해결): #{channel.name}")
        return 0
      end

      ActiveRecord::Base.transaction { materialize(channel, limit) }
    end

    private

    def materialize(channel, limit = nil)
      # 응답에서 이 채널 항목을 id로 정확히 찾는다(배치/스텁이 여러 채널을 반환해도 오배정 방지).
      ch_item = @client.list_channels([channel.youtube_channel_id])
                       .find { |it| it["id"] == channel.youtube_channel_id }
      if ch_item.nil?
        Rails.logger.info("[Youtube] channels.list에 채널 없음(종료/삭제?): #{channel.name}")
        return 0
      end

      # 값이 있을 때만 갱신 — 없는데 nil로 덮어 좋은 스냅샷을 지우지 않는다(hiddenSubscriberCount 등).
      uploads = ch_item.dig("contentDetails", "relatedPlaylists", "uploads")
      subs = ch_item.dig("statistics", "subscriberCount")
      thumb = Youtube::VideoAttributes.thumbnail_url(ch_item.dig("snippet", "thumbnails")) # 채널 아바타.
      # 채널명 = 한국어 현지화(localized.title) 우선, 없으면 기본 제목 — 브라우저(한국어)가 보여주는 이름과 일치.
      name = ch_item.dig("snippet", "localized", "title").presence || ch_item.dig("snippet", "title")
      channel.uploads_playlist_id = uploads if uploads.present?
      channel.subscriber_count = subs.to_i if subs.present?
      channel.thumbnail_url = thumb if thumb.present?
      channel.name = name if name.present?
      channel.save!

      uploads_id = channel.uploads_playlist_id
      if uploads_id.blank?
        Rails.logger.info("[Youtube] uploads 재생목록 미해결 채널 스킵: #{channel.name}")
        return 0
      end

      # limit 있으면 최신순 재생목록에서 앞 N개만 lazy 취득(페이지네이션 조기 종료 → 쿼터 절약).
      enum = @client.each_playlist_item(uploads_id)
      page = limit ? enum.first(limit) : enum.to_a
      ids = page.map { |it| it.dig("contentDetails", "videoId") }.compact.uniq
      items = @client.list_videos(ids)

      items.each { |item| upsert_video(channel, item) }
      items.size
    end

    def upsert_video(channel, item)
      attrs = Youtube::VideoAttributes.from(item)
      # youtube_video_id 는 전역 유니크 — 채널 스코프가 아니라 전역으로 찾아 채널을 (재)연결한다
      # (실 데이터는 video id 가 채널 전속이라 이동 없음. 채널마다 같은 id 를 주는 스텁 다채널 수집도 안 깨진다).
      video = Video.find_or_initialize_by(youtube_video_id: attrs[:youtube_video_id])
      video.channel = channel
      video.title = attrs[:title]
      video.view_count = attrs[:view_count]
      video.like_count = attrs[:like_count]
      video.comment_count = attrs[:comment_count]
      video.duration = attrs[:duration]
      video.published_at = attrs[:published_at]
      video.thumbnail = attrs[:thumbnail]

      # is_short 단일 writer — 미분류(nil)이고 유효 duration(>0)일 때만 1회 설정, 이후 불변.
      # P0D/PT0S(라이브·프리미어)는 0이라 분류를 미룬다(VOD 로 실 duration 이 올 때 1회 분류).
      if video.is_short.nil? && attrs[:duration].to_i.positive?
        video.is_short = Youtube::ClassifyShort.short?(attrs[:duration])
      end

      video.save!
    end
  end
end
