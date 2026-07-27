# Deferred Work

작업 중 리뷰가 부수적으로 발견한, 현재 스토리 소관이 아닌 실제 이슈들을 모은다. 나중에 집중해서 다룬다.

## 키 도착 후 Live 검증 결과 (2026-07-25)

`.env` 에 YOUTUBE_API_KEY·GEMINI_API_KEY 공급됨. Live 어댑터를 최소 실호출로 검증했다(모드는 .env 에서 stub 유지 — 아래 Gemini 빌링 블로커 때문).

- **YouTube Live: ✅ 검증 완료.** `Youtube::Adapters::Live` 로 실 channels.list(공개 채널 1건) 라운드트립 성공. 응답 형태가 녹화 fixture(`lib/youtube/stubs/channels_list.json`)와 일치 — `id`·`statistics.subscriberCount`·`contentDetails.relatedPlaylists.uploads`. spec-2-2 "보류(키 대기)" 중 실호출·형태 대조 부분 해소. (403 분기·페이지네이션 종료의 실 API 재검증은 실제 쿼터 소진 상황이 필요해 미수행 — 저위험.)
- **Gemini Live: ⚠️ 코드는 정상, 계정 빌링 블로커.** `Embedding::Adapters::Live` 가 요청을 올바로 구성·전송했고 실 API 가 응답했으나 `HTTP 429 RESOURCE_EXHAUSTED — "Your prepayment credits are depleted"`. 즉 **GEMINI_API_KEY 계정에 선불 크레딧이 없다**(코드 문제 아님). **사용자 조치 필요**: ai.studio(https://ai.studio/projects)에서 빌링 충전. 충전 전까지 EMBEDDING_MODE 는 stub 유지 — live 로 바꾸면 임베딩 의존 파이프라인(Epic 4 OwnVideoMatch·콘텐츠 갭·주제 클러스터, Epic 5 추천)이 429 로 실패한다. 반쪽 실데이터(실 영상 제목 + 가짜 해시 임베딩)는 정직성 위반이라 회피.
- **모드 전환 정책**: Gemini 빌링 충전 완료 후 YOUTUBE_API_MODE·EMBEDDING_MODE 를 함께 live 로 전환하고 일일 수집 체인을 1회 실행해 실데이터 물질화. 그 전까지는 일관된 stub 파이프라인 유지(혼합 상태 금지).

## 리뷰 발견 항목 (MVP 무관·미래 스케일)

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-rails-bootstrap-multidb.md`
  summary: 큐 DB 커넥션 pool(`RAILS_MAX_THREADS`||5)이 Solid Queue 워커 동시성(processes × threads + dispatcher + recurring)보다 작을 수 있어 프로덕션 부하 시 `ConnectionTimeoutError` 여지가 있다.
  evidence: `config/database.yml`의 pool은 웹 스레드 기준 기본값인데 `config/queue.yml`의 워커 스레드/프로세스와 분리 튜닝되지 않는다. MVP(내부 2인·주1회, NFR-5 저동시성)에선 무해하나 프로덕션 스케일에서 재검토 필요.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-tailwind-tokens.md`
  summary: Pretendard·Noto Sans KR/JP woff2 self-host(@font-face 또는 @fontsource 번들)가 미구현 — 현재는 시스템 폰트 폴백(system-ui·Hiragino·Yu Gothic·Meiryo)에 의존한다.
  evidence: DESIGN.md §2.1은 KR/JP 글리프 정합을 위해 Noto Sans KR/JP self-host를 권한다. 스택은 config에 설정됐고 시스템 폴백이 KR/JP를 커버하나, Pretendard 브랜드 폰트·정확한 일본어 금칙 렌더는 실제 폰트 번들 시 개선된다. MVP 무관, 폴리시 단계 작업.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-scoring-config-secrets.md`
  summary: test 환경에서 YOUTUBE_API_MODE/EMBEDDING_MODE 를 stub 로 강제하지 않아, dotenv 가 로드한 .env 의 실제 키·모드가 test ENV 에 남는다 — 미래 테스트가 우발적으로 live 경로를 타면 실제 API 를 호출할 수 있다.
  evidence: dotenv-rails 가 dev/test 에서 .env 를 로드한다. 현재는 모드를 소비하는 코드가 없어 무해하나, Epic 2·4 가 stub/live 분기를 구현할 때 test 환경 기본을 stub 로 고정해야 안전하다(사용자의 스텁 개발 전략 정합).

- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-channel-video-models.md`
  summary: Story 2.2가 handle-only 시드 채널을 API로 실제 UC 채널ID로 해결할 때, 이미 UC-id로 존재하는 행과 youtube_channel_id 유니크 인덱스에서 충돌할 수 있고 병합 경로가 없다. handle 부분 유니크 인덱스를 dedup 앵커로 두었으니, 2.2는 handle로 기존 행을 찾아 in-place UPDATE(또는 merge)로 id를 부여해야 한다(seed 파일을 편집해 UC-id를 넣고 재시드하면 중복 생성됨).
  evidence: youtube_channel_id 유니크(nil 다중)·handle 부분 유니크. 시드 dedup 키는 youtube_channel_id>handle>name. 3-tier 키는 정적 시드엔 idempotent하나 API 해결로 식별자가 바뀌면 재시드가 중복을 만든다. 会社員A/J는 단일 행이 두 실채널을 표현 — 2.2 해결 시 하나로 발산.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-channel-video-models.md`
  summary: Channel `has_many :videos, dependent: :destroy` 는 채널 destroy 시 수집된 영상·(향후)스냅샷 이력을 cascade 삭제한다. 설계는 은퇴를 excluded 불리언으로 처리하지만 destroy를 막지 않는다.
  evidence: AD-17은 스냅샷 이력을 소급 재구성 불가·일일 백업 필수로 규정. 채널 삭제 흐름이 도입되면 dependent 전략을 restrict_with_exception 등으로 재검토해 이력 유실을 막아야 한다. MVP엔 destroy 경로 없음.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-youtube-boundary-quota.md`
  summary: [보류(키 대기)] Youtube::Adapters::Live 의 실 YouTube 응답 검증은 API 키가 있어야 가능하다. HTTP 골격·엔드포인트·403 reason 분기(quotaExceeded↔rateLimit)·타임아웃·JSON 파싱은 완성됐으나 실 라운드트립은 미검증. 키 도착 시 YOUTUBE_API_MODE=live + YOUTUBE_API_KEY 설정 후, 녹화 fixture(lib/youtube/stubs/*.json)를 실응답과 대조해 형태 일치를 확인하고, 403 분기·페이지네이션 종료를 실 API로 재검증한다.
  evidence: Story 2.2는 경계·쿼터·백오프·배치·스텁을 스텁에 대고 완결·테스트했다(87 runs). Live 경로만 네트워크·키 부재로 단위 error-path만 검증됨.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-2-youtube-boundary-quota.md`
  summary: Youtube::Client#batched_items 는 배치 중 하나가 실패(재시도 소진 RateLimited/QuotaExceeded)하면 완료된 배치 items 를 버리고 예외를 올린다(all-or-nothing). 쿼터는 이미 소비된 상태다.
  evidence: 20채널 일일 수집에서 중간 채널이 쿼터 상한에 걸리면 앞 채널 데이터가 유실되고 다음 주기에 재페치(쿼터 재소비)한다. 2.3/2.5 잡이 채널/배치별로 증분 저장(부분 진행 커밋)하도록 설계해 재페치 낭비를 막아야 한다.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-4-daily-snapshots-rollup.md`
  summary: VideoDailyStat/ChannelDailyStat 에 `has_many :daily_stats, dependent: :destroy` — channel.destroy 시 channel→videos→daily_stats 까지 cascade 삭제돼 AD-17 "소급 재구성 불가·백업 필수" 시계열이 영구 소실될 수 있다.
  evidence: 설계는 은퇴를 excluded(soft)로 처리하지만 destroy 경로에 가드가 없다. 채널 삭제 흐름이 생기면 dependent 를 restrict_with_exception 등으로 바꿔 exclude-not-delete 를 강제하거나 백업-선행 계약을 둬야 한다. MVP엔 destroy 경로 없음(2.1 Video dependent:destroy defer 의 확장).

- source_spec: `_bmad-output/implementation-artifacts/spec-2-6-weekly-discovery-job.md`
  summary: WeeklyDiscoveryJob 의 auto 채널 dedup 이 youtube_channel_id 만 봐서, handle-only 시드 채널(youtube_channel_id nil)과 같은 실채널을 중복 auto 행으로 만든다. Live 발굴 시 2.2/2.3 handle→UC id 해결이 이 중복과 유니크 인덱스 충돌.
  evidence: 시드 대부분이 handle-only(youtube_channel_id nil). 발굴은 UC id 를 주므로 exists?(youtube_channel_id:)가 시드를 못 찾아 중복 생성. 2.1/2.2 handle→id 해결 deferred 를 auto 채널 merge/reconcile 까지 확장해야 한다(키 도착·Live 시). 현재 stub 은 합성 UC 라 미도달.

- source_spec: `_bmad-output/implementation-artifacts/spec-2-6-weekly-discovery-job.md`
  summary: auto 발굴 채널의 name 이 search snippet.title 없을 때 channel_id(UC…) 폴백으로 생성되고, 이후 어떤 잡도 갱신하지 않아 UC id 가 화면 이름으로 영속한다.
  evidence: FetchChannelVideos(2.3)는 uploads·subscriber 만 갱신하고 name 은 안 건드린다. channels.list part 에 snippet 추가 후 name 을 snippet.title 로 보정하면 해소(Live-only·실 search 는 대개 title 존재라 희소).

- source_spec: `_bmad-output/implementation-artifacts/spec-3-1-baseline-median.md`
  summary: is_short nil(미분류) 영상은 CalculateBaseline 표본에서 두 유형 모두 빠져, "데이터 수집 중/미분류" 채널이 low_confidence(저신뢰)로 오표시된다.
  evidence: `where(is_short: bool)`가 SQL 3치 논리로 NULL을 short·long 양쪽에서 제외. 분류 전 채널은 표본 0→low_confidence. 데이터층 계산은 옳지만(유형 분리), 화면 정직성 상태(DESIGN.md §4.7)는 "미분류"와 "저신뢰"를 구분해야 한다 — Epic 6 표시에서 미분류 카운트를 별도 신호로 노출.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-1-baseline-median.md`
  summary: CalculateBaseline 의 find_or_initialize_by+update! 는 동일 채널 동시 재계산 시 unique index(channel,video_type) 경합으로 RecordNotUnique 를 던진다.
  evidence: 두 워커가 각각 미저장 레코드를 초기화 후 INSERT → 두 번째가 유니크 위반. 모델 uniqueness 검증은 read-then-write라 경합 방지 못함. 현재 recurring 잡은 reap_stale·직렬 실행이라 미도달이나, 잡 병렬화·수동 재계산 병행 시 upsert 또는 with_lock 필요.

- source_spec: `_bmad-output/implementation-artifacts/spec-3-2-performance-multiple.md`
  summary: CalculatePerformance 의 find_or_initialize_by(video:)+update! 는 동일 채널 동시 재계산 시 video_scores unique(video_id) 경합으로 RecordNotUnique 를 던진다(3.1 CalculateBaseline 과 동일 클래스).
  evidence: 두 워커가 각각 미저장 VideoScore 를 초기화 후 INSERT → 두 번째가 유니크 위반. 모델 uniqueness 검증은 read-then-write라 경합 방지 못함. 현재 recurring 잡은 직렬 실행이라 미도달이나, 잡 병렬화·수동 재계산 병행 시 스코어링 서비스 전반에 upsert_all(unique_by) 또는 with_lock 도입 필요.

- source_spec: `_bmad-output/implementation-artifacts/spec-6-1-shared-display-components.md`
  summary: `_video_row` 제목 셀의 per-title 언어(lang) 힌트 — 현재 한·일 혼재라 단일 하드코딩 lang 은 절반을 오표시해 제거했다. 제목별 언어 감지 후 lang 을 정확히 부착하면 스크린리더 발음·CJK 폰트 선택이 개선된다(향후).
  evidence: FR-24/§7 다국어 방어는 폰트 폴백·break-keep·line-clamp·min-w-0·title 툴팁으로 충족되나, lang 속성은 언어 감지 없이는 정확히 못 준다. 제목 언어 감지(간이 스크립트 판별 등) 도입 시 lang 재부착.

- source_spec: `_bmad-output/implementation-artifacts/spec-6-2-dashboard-home.md`
  summary: 대시보드 기간 탭·카테고리/유형 필터·밴드 그룹핑↔평면 토글이 URL 상태·컨트롤까지만 — 실제 대상(급상승 비디오 테이블)이 6.2엔 없다. 6.3이 @period/@category/@type/@layout 을 테이블 쿼리·구독자 밴드 그룹핑 렌더링에 적용해야 필터가 눈에 보이게 동작한다.
  evidence: 추천 카드는 배치 top-3라 기간·카테고리 미scope(주간 고정). 필터의 실 타깃은 급상승 영상 테이블(6.3). 6.2는 컨트롤·화이트리스트 파라미터·URL 상태를 제공(재클릭 시 파라미터 병합은 이번에 수정). 6.3 착수 시 파라미터를 Video 스코프·밴드 그룹핑에 적용.

- source_spec: `_bmad-output/implementation-artifacts/spec-6-2-dashboard-home.md`
  summary: 추천 카드 태그 칩(§4.2 목업의 문법/초급~중급 같은 장르·레벨 칩)이 데이터 소스 부재로 생략됐다.
  evidence: Recommendation/TopicCluster에 장르·난이도 컬럼이 없어 칩을 날조하지 않고 생략했다(제목 위 슬롯 자리만). 향후 topic_label 에서 파생하거나 별 분류 소스를 두면 §4.2 칩 블록을 복원.

## 데이터 보존·갱신 티어링 설계 (미구현 — 배포 성장기, 운영자와 합의 2026-07-27)

**결정: 현 규모(영상 ~6천)에선 구현하지 않는다.** 발동 조건이 한참 멀고(아래 티핑포인트), 임계값은 실측 시계열 없이는 근거를 못 가진다. 근거 없는 임계가 고객사 프로덕션에서 처음 발동하는 리스크를 피해, 배포 후 데이터가 커질 때 실측 감쇠 곡선을 보고 스토리로 구현한다. 지금은 이 설계만 기록.

**바로잡은 사실(핵심)**: YouTube Data API 한도는 "요청 1만"이 아니라 **1만 유닛/일**이고, `videos.list`는 **1유닛에 영상 50개** 통계를 배치로 가져온다(코드 `Youtube::Client::BATCH_SIZE=50`, "호출당 1유닛" 주석; 백필 실측 ~3천 영상 수집에 199유닛). 따라서:
- 통계 갱신 티핑포인트 ≈ **50만 영상**(1만 유닛 × 50)을 매일 전부 갱신할 때. 그 밑에선 전부 매일 갱신해도 쿼터 무압박.
- **쿼터는 대부분 고객사(수만~십수만 영상)에서 제약이 아니다.** 티어링은 "초대형 라이브러리 안전밸브".
- 쿼터보다 **먼저 걸리는 진짜 제약**: (1) 일일 잡 실행 시간(수십만 영상 처리), (2) `video_daily_stats` 스냅샷 테이블 증가(하루 수십만 행), (3) Gemini 임베딩 비용(신규 영상당 1회·실 과금, 배치 덜 됨).

**티어링 모델(행동 기반, 나이 아님)**:
- HOT(매일)·WARM(주간)·COLD(월간). 어떤 티어냐는 **나이 절댓값이 아니라 조회수 속도(behavior)**로 결정.
- 강등: 일별 Δ가 유의미성 임계(기존 `min_material_pct` 개념 재사용, 0 아님) 아래로 **N일 연속** → WARM, WARM에서 **M주 연속** 잠잠 → COLD.
- **★ 승격(양방향, 필수)**: WARM/COLD가 (주간/월간) 체크에서 **유의미 급증** 보이면 즉시 HOT 재승격. 재유행·알고리즘 재노출·시즌성 에버그린을 놓치지 않게. COLD는 "동결"이 아니라 "가끔 체크하되 깨어남".
- 히스테리시스: 강등은 N연속 후 신중, 승격은 1회 급증으로 즉시(비대칭) → 티어 플래핑 방지.
- 신규 영상은 HOT 시작.
- **에버그린과의 시너지**: "오래됐지만 HOT에 남는 영상" = 에버그린 정의(오래+지속 조회)와 사실상 동일. 티어링과 에버그린 판정이 같은 시계열·같은 유의미성 기준을 공유하게 설계.

**발동 트리거(고정 개수·비율 금지)**: "영상 개수 N 초과" 같은 하드코딩이 아니라 **"매일 갱신 수요(= HOT 후보 수 ÷ 50 유닛) > 예산"**일 때만. 예산 초과 시 **비율(5/3/2 등) 강제 대신 활동 순으로 위에서부터 채우기** — HOT을 예산 한도까지 채우고 넘치면 WARM, 또 넘치면 COLD. 티어가 데이터+예산에서 emergent하게 나오게(예산 남으면 다 HOT 유지 → 낭비 없음).

**동반 작업**: 스냅샷 롤업(spec-2-4-daily-snapshots-rollup 확장) — 최근 90일 일 단위, 이후 주/월 압축으로 `video_daily_stats` 행 증가 바운드. 같은 트리거에 묶는다.

**전부 config + 실측 튜닝**(AD-4): 예산(유닛), N·M 연속-잠잠 카운트, 유의미성 임계, 롤업 경계. 초기 추정값으로 두되 감쇠 곡선 실측 후 확정. 캘리브레이션 기간(초기엔 전부/표본 매일 수집해 곡선 학습 → 그 뒤 티어 적용)의 닭-달걀 고려.
