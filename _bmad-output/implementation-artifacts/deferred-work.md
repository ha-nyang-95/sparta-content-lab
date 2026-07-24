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
