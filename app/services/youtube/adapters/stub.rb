# 녹화된 실 API 형태 fixture 를 반환하는 스텁 어댑터 — 키 없이 파이프라인 개발용(STUB 로그로 표식)
module Youtube
  module Adapters
    class Stub
      STUB_DIR = Rails.root.join("lib", "youtube", "stubs")

      # endpoint 심볼 → fixture 파일명. Live 어댑터와 같은 엔드포인트 키를 공유한다.
      FIXTURES = {
        channels_list: "channels_list.json",
        playlist_items_list: "playlist_items_list.json",
        videos_list: "videos_list.json",
        search_list: "search_list.json"
      }.freeze

      # fetch(endpoint, params) -> Hash(파싱된 JSON). params 는 스텁에선 무시되나 계약상 받는다.
      # 매 호출마다 "아직 진짜 아님" 표식을 로그로 남긴다(스텁을 진짜인 척 만들지 않기).
      def fetch(endpoint, params = {})
        Rails.logger.info("[Youtube] STUB 모드 — 녹화 fixture 반환: #{endpoint}")
        filename = FIXTURES.fetch(endpoint) do
          raise Youtube::Error, "알 수 없는 endpoint: #{endpoint.inspect} (fixture 없음)"
        end

        data =
          begin
            JSON.parse(File.read(STUB_DIR.join(filename)))
          rescue Errno::ENOENT
            raise Youtube::Error, "fixture 파일 없음: #{filename}"
          end

        # 페이지네이션 종료: pageToken이 있는(=2페이지 이후) playlistItems 호출은 nextPageToken을
        # 떼어 마지막 페이지로 만든다. 정적 스텁이 무한 페이지가 되지 않게 한다(실 API는 결국 토큰을 끊는다).
        if endpoint == :playlist_items_list && params[:pageToken].present?
          data = data.except("nextPageToken")
        end

        # channels.list는 실 API처럼 요청한 id 를 그대로 반환한다(1채널당 1 item).
        # 정적 fixture의 첫 채널을 템플릿으로 삼아 요청 id 별 item 을 만든다(다채널·id 매칭 정합).
        if endpoint == :channels_list && params[:id].present?
          data = echo_channel_ids(data, params[:id])
        end
        data
      end

      private

      # 요청 id(콤마 구분)마다 fixture 템플릿을 복제하고 id 를 요청값으로 덮어 반환한다.
      def echo_channel_ids(data, id_param)
        template = data["items"]&.first
        return data if template.nil?

        items = id_param.to_s.split(",").map do |id|
          template.merge("id" => id)
        end
        data.merge("items" => items)
      end
    end
  end
end
