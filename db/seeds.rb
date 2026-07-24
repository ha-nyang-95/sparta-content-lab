# 운영 2인을 idempotent하게 등록하는 seed (재실행해도 중복 없음)
#
# 실존 인물을 날조하지 않는다 — dev 기본값은 문서화된 placeholder다.
# 실제 운영자 이메일·비밀번호는 ENV로 재정의한다:
#   SEED_OPERATOR1_EMAIL / SEED_OPERATOR2_EMAIL / SEED_OPERATOR_PASSWORD
# 기본 비밀번호는 development/test 전용이며, 그 외 환경에서는 SEED_OPERATOR_PASSWORD를 반드시 명시한다
# (커밋된 기본값이 프로덕션 계정에 쓰이는 것을 막는다 — 회원가입이 없어 seed 계정이 전체 접근면이다).

env_presence = ->(name) { ENV[name].to_s.strip.presence }

emails = [
  env_presence.("SEED_OPERATOR1_EMAIL") || "operator1@sparta.local",
  env_presence.("SEED_OPERATOR2_EMAIL") || "operator2@sparta.local",
]

# 두 이메일이 (정규화 후) 겹치면 "운영 2인" 불변식이 조용히 깨진다 — 중단한다.
if emails.map { |e| e.strip.downcase }.uniq.size < emails.size
  raise "seed 중단: 두 운영자 이메일이 서로 달라야 한다 (#{emails.inspect})"
end

password = env_presence.("SEED_OPERATOR_PASSWORD")
if password.nil?
  unless Rails.env.local? # local? = development || test
    raise "seed 중단: #{Rails.env} 환경에서는 SEED_OPERATOR_PASSWORD를 반드시 설정해야 한다"
  end
  password = "change-me-in-dev" # dev/test 전용 — 프로덕션은 ENV 필수, 첫 로그인 후 교체
end

emails.each do |email|
  User.find_or_create_by!(email_address: email) { |u| u.password = password }
end

# --- 경쟁/참고 채널 시드 (docs/research/channel-analysis.md §5) ---
#
# §5의 4 카테고리를 Channel.category 4분류로 매핑하고 전부 source: "seed"로 로드한다.
# 시드 현실: 대부분 @handle/이름만 있고 실제 채널ID(UC…)·구독자수는 미확정이다.
# 미확정 값은 추측으로 채우지 않고 nil로 둔다 — Story 2.2/2.3이 API로 해결한다.
#   - youtube_channel_id: 핸들/URL 컬럼이 /channel/UC… 인 경우에만 UC id 추출
#   - handle           : 핸들/URL 컬럼의 @handle 또는 URL. "검색 유입"(핸들 미상)·UC-URL은 nil → name 으로 dedup
#   - subscriber_count : "구독자(대략)" 컬럼의 단일 명시 근사만 정수화("약 21만"→210000).
#                        그 컬럼이 범위("14~15만")·합산("200만+")·"확인 불가"면 nil (날조 금지).
#                        ※ "검색 유입"은 핸들 컬럼 마커이지 구독자 값이 아니다 — 별도 컬럼의 근사가 있으면 그대로 쓴다.
#   - idempotency      : youtube_channel_id > handle > name 순의 안정 키로 find_or_create_by!
seed_channels = [
  # 카테고리 1 → 직접경쟁
  { name: "トリリンガルのトミ【韓国語講座】", category: "직접경쟁", handle: "@TrilingualTomi", youtube_channel_id: nil, subscriber_count: nil }, # 약 14~15만(범위)→nil
  { name: "JOO【じゅー】ちょっと楽しくなる韓国語", category: "직접경쟁", handle: nil, youtube_channel_id: "UCgwCe_1IWTaXEy7wFUNbaHA", subscriber_count: 210_000 },
  { name: "다히 Dahi【韓国語講座】", category: "직접경쟁", handle: nil, youtube_channel_id: "UCEL0UHw8k4q9XHQ6WYi2kkA", subscriber_count: nil }, # 확인 불가
  { name: "サットン★韓国語先生", category: "직접경쟁", handle: "@satton_korean101", youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "seemile 韓国語 (For Japanese)", category: "직접경쟁", handle: "@seemile", youtube_channel_id: nil, subscriber_count: nil }, # 채널 전체 150만+(개별 미확정)→nil
  { name: "コリアンテナ / オンライン韓国語教室", category: "직접경쟁", handle: "@KoreAntenna", youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "미사닝 みさにん", category: "직접경쟁", handle: nil, youtube_channel_id: nil, subscriber_count: 190_000 }, # 약 19만, 검색 유입(이름만)

  # 카테고리 2 → 한국어교육일반
  { name: "Talk To Me In Korean (TTMIK)", category: "한국어교육일반", handle: "@talktomeinkorean", youtube_channel_id: nil, subscriber_count: 1_600_000 },
  { name: "Talk To Me In 100% Korean", category: "한국어교육일반", handle: "@TalkToMeIn100Korean", youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "GO! Billy Korean", category: "한국어교육일반", handle: "@gobillykorean", youtube_channel_id: nil, subscriber_count: 800_000 },
  { name: "Korean Unnie", category: "한국어교육일반", handle: nil, youtube_channel_id: nil, subscriber_count: 1_300_000 }, # 약 130만, 검색 유입(이름만)

  # 카테고리 3 → 언어교육참고
  { name: "だいじろー Daijiro", category: "언어교육참고", handle: "@daijirojp", youtube_channel_id: nil, subscriber_count: 680_000 },
  { name: "あいうえおフォニックス", category: "언어교육참고", handle: nil, youtube_channel_id: nil, subscriber_count: 350_000 }, # 약 35만, 검색 유입(이름만)
  { name: "Kevin's English Room", category: "언어교육참고", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "英語聞き流し Sakura English", category: "언어교육참고", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가

  # 카테고리 4 → 상단퍼널
  { name: "KaoruTV", category: "상단퍼널", handle: "@KaoruTV819", youtube_channel_id: nil, subscriber_count: 905_000 }, # 약 90만(905K 확인)
  { name: "会社員A / 会社員J", category: "상단퍼널", handle: nil, youtube_channel_id: "UCN559lrbV9wt46NwlnPJtPw", subscriber_count: nil }, # 합산 200만+ → nil
  { name: "ミョリム Myorimu", category: "상단퍼널", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "留学生じん", category: "상단퍼널", handle: nil, youtube_channel_id: nil, subscriber_count: 97_000 }, # 약 9.7만, 검색 유입(이름만)
  { name: "あゆたび", category: "상단퍼널", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
]

seed_channels.each do |attrs|
  dedup_key =
    if attrs[:youtube_channel_id].present?
      { youtube_channel_id: attrs[:youtube_channel_id] }
    elsif attrs[:handle].present?
      { handle: attrs[:handle] }
    else
      { name: attrs[:name] }
    end

  Channel.find_or_create_by!(dedup_key) do |c|
    c.name = attrs[:name]
    c.category = attrs[:category]
    c.handle = attrs[:handle]
    c.youtube_channel_id = attrs[:youtube_channel_id]
    c.subscriber_count = attrs[:subscriber_count]
    c.uploads_playlist_id = nil # 2.2/2.3이 API로 해결
    c.source = "seed"
    c.excluded = false
  end
end
