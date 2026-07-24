# 영상 저장 토글(쓰기) — 현재 사용자 스코프로 저장(create)·해제(destroy). 인증 상속·CSRF(button_to)
class SavedVideosController < ApplicationController
  def create
    Current.user.saved_videos.find_or_create_by!(video_id: params[:video_id])
    redirect_back(fallback_location: saved_path, notice: "저장했습니다.")
  rescue ActiveRecord::RecordNotUnique
    # 동시/이중 제출 경합 — find_or_create 의 SELECT↔INSERT 창에서 유니크 인덱스가 잡는다.
    # 원하는 상태(이미 저장됨)가 달성됐으므로 성공으로 흡수(500 방지).
    redirect_back(fallback_location: saved_path, notice: "저장했습니다.")
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    redirect_back(fallback_location: saved_path, alert: "저장할 수 없는 영상입니다.")
  end

  def destroy
    Current.user.saved_videos.where(video_id: params[:video_id]).destroy_all
    redirect_back(fallback_location: saved_path, notice: "저장을 해제했습니다.")
  end
end
