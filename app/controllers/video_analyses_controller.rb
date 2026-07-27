# 영상 기획 분석 — 클릭 시 모달이 부르는 온디맨드 엔드포인트. 캐시 있으면 즉시, 없으면 생성 후 저장(AD-3 물질화).
class VideoAnalysesController < ApplicationController
  def show
    video = Video.find(params[:id])
    analysis = video.video_analysis || Analysis::Generate.new.call(video)
    render json: serialize(video, analysis)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "영상을 찾을 수 없습니다." }, status: :not_found
  end

  private

  def serialize(video, analysis)
    {
      status: analysis.status,
      detail: analysis.detail,
      intro_excerpt: analysis.intro_excerpt,
      intro_analysis: analysis.intro_analysis,
      summary: analysis.summary,
      overall_analysis: analysis.overall_analysis,
      title: video.title,
      url: helpers.youtube_watch_url(video)
    }
  end
end
