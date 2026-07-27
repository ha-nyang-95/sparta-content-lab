# 원어 자막(스크립트) 추출 — yt-dlp 로 영상 메타를 받아 원어 트랙(수동 우선·없으면 원어 auto)을 내려받아 순수 텍스트화
require "open3"
require "tmpdir"
require "json"

module Analysis
  class Transcript
    # youtube_video_id → 자막 순수 텍스트(없으면 nil). 번역 자막이 아니라 '원어' 트랙만 고른다(번역은 품질 쓰레기).
    def call(youtube_video_id)
      url = "https://www.youtube.com/watch?v=#{youtube_video_id}"
      info = dump_json(url)
      return nil if info.nil?

      lang = pick_lang(info)
      return nil if lang.blank?

      Dir.mktmpdir do |dir|
        return nil unless download_sub(url, lang, dir)

        vtt = Dir.glob(File.join(dir, "*.vtt")).first
        vtt && to_text(File.read(vtt)).presence
      end
    end

    private

    # 영상 메타 JSON(언어·자막 목록). 실패 시 nil(429·비공개·삭제 포함).
    def dump_json(url)
      out, status = Open3.capture2("yt-dlp", "--dump-single-json", "--skip-download", "--no-warnings", url)
      status.success? ? JSON.parse(out) : nil
    rescue StandardError => e
      Rails.logger.warn("[Analysis::Transcript] dump-json 실패: #{e.class}: #{e.message}")
      nil
    end

    # 원어 결정 — 영상 language 에 (수동/원어 auto) 자막이 있으면 그 언어, 없으면 수동자막 언어 아무거나, 그것도 없으면 nil.
    def pick_lang(info)
      lang = info["language"].presence
      return lang if lang && (info.dig("subtitles", lang) || info.dig("automatic_captions", lang))

      (info["subtitles"] || {}).keys.first
    end

    def download_sub(url, lang, dir)
      _out, status = Open3.capture2e(
        "yt-dlp", "--skip-download", "--write-subs", "--write-auto-subs",
        "--sub-langs", lang, "--sub-format", "vtt", "--no-warnings",
        "-o", File.join(dir, "%(id)s.%(ext)s"), url
      )
      status.success?
    rescue StandardError => e
      Rails.logger.warn("[Analysis::Transcript] 자막 다운로드 실패: #{e.class}: #{e.message}")
      false
    end

    # VTT → 순수 텍스트(헤더·타임스탬프·인라인 태그·중복 줄 제거).
    def to_text(vtt)
      vtt.lines
         .reject { |l| l =~ /^WEBVTT|^Kind:|^Language:|-->|\A\s*\z|\A\d+\s*\z/ }
         .map { |l| l.gsub(/<[^>]+>/, "").strip }
         .reject(&:blank?)
         .uniq
         .join(" ")
    end
  end
end
