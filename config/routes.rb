Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # 앱 셸 6개 화면 placeholder 라우트 (Story 1.4) — 후속 에픽이 각 index 를 채운다.
  get "popular", to: "popular#index"
  get "competitors", to: "competitors#index"
  # 6.4 경쟁 채널 쓰기 액션 — 수동 등록(create)·제외 토글(toggle_exclusion). index 는 위 GET.
  post "competitors" => "competitors#create"
  patch "competitors/:id/exclusion" => "competitors#toggle_exclusion", as: :competitor_exclusion
  get "content-gap", to: "content_gap#index", as: :content_gap
  get "saved", to: "saved#index"
  # 7.2 영상 저장 토글(쓰기) — create(POST)·destroy(DELETE) 모두 video_id 파라미터로 키. 읽기는 위 GET saved.
  resources :saved_videos, only: [:create]
  delete "saved_videos", to: "saved_videos#destroy", as: :destroy_saved_video
  get "settings", to: "settings#index"
  # 헤더 실시간 검색(타입어헤드) — 제목 부분일치 상위 5건 JSON. '모두 보기'는 popular?q= 로.
  get "search", to: "search#index", as: :search

  # '오늘 업데이트' — 수집 트리거(POST)·진행 상태 폴링(GET status). 게이지 UI 가 소비한다.
  post "collections", to: "collections#create"
  get "collections/status", to: "collections#status", as: :collection_status

  # Defines the root path route ("/")
  root "dashboard#index"
end
