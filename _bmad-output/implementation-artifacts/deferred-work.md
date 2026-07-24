# Deferred Work

작업 중 리뷰가 부수적으로 발견한, 현재 스토리 소관이 아닌 실제 이슈들을 모은다. 나중에 집중해서 다룬다.

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
