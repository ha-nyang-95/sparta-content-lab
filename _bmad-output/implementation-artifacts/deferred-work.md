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
