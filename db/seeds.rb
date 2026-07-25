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
  # 확장(2026-07-25 웹 조사, 라이브 채널 페이지 직접 확인) — 주제 다양성: 종합/회화/발음/문법/흘려듣기/여행/K-드라마
  { name: "アンニョン韓国語教室", category: "직접경쟁", handle: "@hello_Korean", youtube_channel_id: "UCdh0XuhsJaa2taxM6FoWPwQ", subscriber_count: 300_000 },
  { name: "オヌルド韓国語[오늘도 한국어]", category: "직접경쟁", handle: "@oneuldokankokugo", youtube_channel_id: "UCUL9G77LWlCpJq5f8gY9D-w", subscriber_count: 185_000 },
  { name: "Twoi「すぐ使える韓国語」", category: "직접경쟁", handle: "@twoikorean", youtube_channel_id: "UCWj9XWiR3Kyz0U_RmiVrMPg", subscriber_count: 136_000 },
  { name: "聞き流し韓国語CH", category: "직접경쟁", handle: "@KoreanListening", youtube_channel_id: "UCru-Nq6ymuYMZGWLfAXepag", subscriber_count: 66_200 },
  { name: "ハングルノート加藤", category: "직접경쟁", handle: "@hangulnote", youtube_channel_id: nil, subscriber_count: 59_900 }, # UC id 미확인 → nil
  { name: "でき韓 韓国語講座_パク先生", category: "직접경쟁", handle: "@dekikanhangul", youtube_channel_id: "UC15dEhfMWAgwW0dsr9rC7MA", subscriber_count: 42_200 },
  { name: "「韓国語は『発音』が9割」スンジュン", category: "직접경쟁", handle: "@seungseung10", youtube_channel_id: "UCCxS_ExpILN5I817YKvwhQA", subscriber_count: 39_600 },
  { name: "TAONの韓国語講座", category: "직접경쟁", handle: "@taongogaku", youtube_channel_id: "UCotG2q84rKblIfCCttq61Ug", subscriber_count: 14_800 },

  # 카테고리 2 → 한국어교육일반
  { name: "Talk To Me In Korean (TTMIK)", category: "한국어교육일반", handle: "@talktomeinkorean", youtube_channel_id: nil, subscriber_count: 1_600_000 },
  { name: "Talk To Me In 100% Korean", category: "한국어교육일반", handle: "@TalkToMeIn100Korean", youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "GO! Billy Korean", category: "한국어교육일반", handle: "@gobillykorean", youtube_channel_id: nil, subscriber_count: 800_000 },
  { name: "Korean Unnie", category: "한국어교육일반", handle: nil, youtube_channel_id: nil, subscriber_count: 1_300_000 }, # 약 130만, 검색 유입(이름만)
  # 확장(2026-07-25 웹 조사, 라이브 채널 페이지 직접 확인) — 종합/회화/초급/발음/TOPIK/몰입/문화/스페인어권/K-pop
  { name: "Learn Korean with KoreanClass101.com", category: "한국어교육일반", handle: "@KoreanClass101", youtube_channel_id: "UCsgBUobNGksxIKTagZayKEw", subscriber_count: 4_100_000 },
  { name: "Korean with Miss Vicky 빅키쌤", category: "한국어교육일반", handle: "@KoreanwithMissVicky", youtube_channel_id: "UCJpIsrXze5HT3X64LDIIHUg", subscriber_count: 592_000 },
  { name: "Study Korean Together", category: "한국어교육일반", handle: "@StudyKoreanTogether", youtube_channel_id: "UC2KZqsHpA6jOagwW1vqf7YA", subscriber_count: 267_000 },
  { name: "Learn Korean From Zero!", category: "한국어교육일반", handle: "@koreanfromzero", youtube_channel_id: "UCed10TzRi6H13tyRBHyljhw", subscriber_count: 261_000 },
  { name: "masterTOPIK", category: "한국어교육일반", handle: "@MasterTOPIK", youtube_channel_id: "UCcU6RCjsoPqJ7HtiIpLmyyw", subscriber_count: 248_000 },
  { name: "Minji Teaches Korean 민지 티치 코리안", category: "한국어교육일반", handle: "@minjiteacheskorean", youtube_channel_id: "UCT4rIm6Ibb-Jb8Vj23Ur3BA", subscriber_count: 224_000 },
  { name: "Pronounce Korean", category: "한국어교육일반", handle: "@Pronounce-Korean", youtube_channel_id: "UC53Xhkp-t4MreRGRk1vbnWQ", subscriber_count: 186_000 },
  { name: "몰입한국어 Immersion in Korean", category: "한국어교육일반", handle: "@morip.korean", youtube_channel_id: "UC-3wHyVaLCiujjjPYXtif5w", subscriber_count: 167_000 },
  { name: "sweetandtastyTV", category: "한국어교육일반", handle: "@sweetandtastyTV", youtube_channel_id: "UC9aWBNR-mDNzgRsO3XLJ7uw", subscriber_count: 1_170_000 },
  { name: "Hablo Coreano", category: "한국어교육일반", handle: "@HabloCoreano", youtube_channel_id: "UCSn2ct7PCfa5mOxnPWYCRnA", subscriber_count: 994_000 }, # 스페인어권
  { name: "Jaeguchi", category: "한국어교육일반", handle: "@jaeguchi", youtube_channel_id: "UCmth4hMyizG-_W9jidBqs_A", subscriber_count: 5_880_000 }, # K-pop 가사 기반

  # 카테고리 3 → 언어교육참고
  { name: "だいじろー Daijiro", category: "언어교육참고", handle: "@daijirojp", youtube_channel_id: nil, subscriber_count: 680_000 },
  { name: "あいうえおフォニックス", category: "언어교육참고", handle: nil, youtube_channel_id: nil, subscriber_count: 350_000 }, # 약 35만, 검색 유입(이름만)
  { name: "Kevin's English Room", category: "언어교육참고", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "英語聞き流し Sakura English", category: "언어교육참고", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  # 확장(2026-07-25 웹 조사, 서드파티 교차확인 — 구독자는 근사·API 재확인 예정) — 회화/학습법/TOEIC/예능/중국어 등 일본인 대상 어학
  { name: "バイリンガール英会話 | Bilingirl Chika", category: "언어교육참고", handle: nil, youtube_channel_id: "UCPlreGCqby4Qg9Vuem5scpw", subscriber_count: 1_500_000 }, # 핸들 미확인(레거시 URL)
  { name: "三原JAPAN Sanyuan_JAPAN", category: "언어교육참고", handle: "@Sanyuan_JAPAN", youtube_channel_id: "UCCBq7s8VOCyek275uvq5lYQ", subscriber_count: 1_500_000 }, # 중/일/영 멀티링구얼
  { name: "Kazu Languages", category: "언어교육참고", handle: "@KazuLanguages", youtube_channel_id: "UCQlOfsmvWrWDHdopzmoxi2A", subscriber_count: 1_250_000 }, # 폴리글롯 예능
  { name: "Atsueigo", category: "언어교육참고", handle: "@atsueigo", youtube_channel_id: "UCgeaC4OEk0t54m2hWQtjjIw", subscriber_count: 660_000 },
  { name: "ニック式英会話", category: "언어교육참고", handle: "@ニック式英会話", youtube_channel_id: "UCOk5YQTyq6B9lOZ1FqG54Jw", subscriber_count: 540_000 },
  { name: "Hapa 英会話", category: "언어교육참고", handle: "@hapaeikaiwa", youtube_channel_id: "UCsSuev_h2XixlD6FFGADI6w", subscriber_count: 517_000 },
  { name: "英語コーチ-イングリッシュおさる", category: "언어교육참고", handle: "@englishosaru", youtube_channel_id: nil, subscriber_count: 487_000 }, # UC id 미확인 → nil
  { name: "李姉妹ch", category: "언어교육참고", handle: "@lisistersch", youtube_channel_id: "UCDhjThxt99rkGcjcEreyOQg", subscriber_count: 360_000 }, # 중국어 학습·문화비교
  { name: "華音チャンネル", category: "언어교육참고", handle: nil, youtube_channel_id: "UCB48i-3A65IN7bIY0LhhTbw", subscriber_count: 330_000 }, # 핸들 미확인
  { name: "Morite2 English Channel", category: "언어교육참고", handle: "@Morite2Channel", youtube_channel_id: "UC_U7pKOVK-0hGr7bDmy2mng", subscriber_count: 300_000 }, # TOEIC
  { name: "サマー先生と英会話！", category: "언어교육참고", handle: nil, youtube_channel_id: "UC91qteXE1f8puKS8lEBRUhw", subscriber_count: nil }, # 발음, 구독자 미확인 → nil

  # 카테고리 4 → 상단퍼널
  { name: "KaoruTV", category: "상단퍼널", handle: "@KaoruTV819", youtube_channel_id: nil, subscriber_count: 905_000 }, # 약 90만(905K 확인)
  { name: "会社員A / 会社員J", category: "상단퍼널", handle: nil, youtube_channel_id: "UCN559lrbV9wt46NwlnPJtPw", subscriber_count: nil }, # 합산 200만+ → nil
  { name: "ミョリム Myorimu", category: "상단퍼널", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  { name: "留学生じん", category: "상단퍼널", handle: nil, youtube_channel_id: nil, subscriber_count: 97_000 }, # 약 9.7만, 검색 유입(이름만)
  { name: "あゆたび", category: "상단퍼널", handle: nil, youtube_channel_id: nil, subscriber_count: nil }, # 확인 불가
  # 확장(2026-07-25 웹 조사, 라이브+서드파티) — 한일커플/그루메/트렌드/유학/여행/뷰티/워홀/K-drama
  { name: "トモトモ / TomoTomo", category: "상단퍼널", handle: "@zzangtomo", youtube_channel_id: nil, subscriber_count: nil }, # 한일커플, 1.05M은 2022년 값이라 nil
  { name: "Togimochi Koreaとぎもち 토기모치", category: "상단퍼널", handle: "@togimochi", youtube_channel_id: "UC8x_GQsqwLvglizV7xRckpw", subscriber_count: 845_000 }, # 한국 그루메
  { name: "きばるん 키바룬", category: "상단퍼널", handle: "@kibaruuun", youtube_channel_id: "UChXOIsxtfbYbnKnv8wShIYA", subscriber_count: 770_000 }, # 한류 트렌드·한일비교
  { name: "韓国留学生momona", category: "상단퍼널", handle: "@momona", youtube_channel_id: nil, subscriber_count: 590_000 }, # 유학 vlog
  { name: "しやごちゃんねる＠グルメ旅", category: "상단퍼널", handle: "@shiyago", youtube_channel_id: "UCL_ZYXcb07HM4wobK58PcEA", subscriber_count: 374_000 }, # 여행·맛집
  { name: "뿌니ぷに", category: "상단퍼널", handle: nil, youtube_channel_id: "UCARdHl-Fhsfio85JHeu3Thw", subscriber_count: 200_000 }, # 한일커플·한국어학습, 핸들 미확인
  { name: "スプスプちゃんねる", category: "상단퍼널", handle: "@doublesoup_jp", youtube_channel_id: "UCjo-udZqf126Mxp9LCxSNMQ", subscriber_count: 160_000 }, # 한국 뷰티/코스메(일본향)
  { name: "SEAN AMI", category: "상단퍼널", handle: "@SEANAMI", youtube_channel_id: "UCKybuEEYwNiCbZzq3vYKuvQ", subscriber_count: 103_000 }, # 한일부부 생활
  { name: "miniTV【韓国ワーホリ】", category: "상단퍼널", handle: "@miniminiminnie", youtube_channel_id: nil, subscriber_count: nil }, # 워홀, 구독자 미확인 → nil
  { name: "プレイリスト PLAYLIST Japan", category: "상단퍼널", handle: "@PLAYLIST_Japan", youtube_channel_id: nil, subscriber_count: nil }, # K-drama 일본어 자막, 구독자 미확인 → nil
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

# --- 자사 채널 (is_own: true) — 경쟁 시드와 분리한다 (4.2 자사/경쟁 파티션) ---
#
# 실제 자사 채널 @KankokugoBenkyo. is_own:true 로 자사 집합을 표시한다.
# category(4분류)는 순수 필터 축이라 자사도 도메인 category(직접경쟁)를 보유한다.
# name 으로 find_or_create_by! — 재실행해도 중복되지 않는다. 자사 채널은 정의상 is_own:true 여야 하므로,
# 이미 존재하는 행(예: 발굴·수동 등록으로 is_own:false 생성)의 플래그도 복구한다(생성 블록은 create 시에만 실행되므로).
own_channel = Channel.find_or_create_by!(name: "スパルタ韓国語 l 楽しく独学") do |c|
  c.category = "직접경쟁"
  c.source = "seed"
  c.is_own = true
  c.handle = "@KankokugoBenkyo"
end
own_channel.update!(is_own: true) unless own_channel.is_own
