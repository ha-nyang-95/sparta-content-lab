# Epic 1 Context: 기반 · 인증 · 디자인 토큰 (Foundation)

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

운영 2인이 로그인해 앱 셸(좌측 내비 6항목 + 헤더)에 진입하고, 이후 6개 화면이 DESIGN.md 토큰으로 세션마다 어긋남 없이 일관 렌더될 인프라 기반을 세운다. 직접 구현하는 사용자 대면 FR은 적지만 Rails 8 greenfield + SQLite 멀티DB(WAL) + 인증 제너레이터(2인 seed) + Tailwind v3 핀 + DESIGN.md 토큰 이관 + `config/scoring.yml` 자리 + 시크릿 격리가 후속 6개 에픽 전부의 전제다. Epic 1은 후속에 의존하지 않고 독립적으로 완결된다.

## Stories

- Story 1.1: Rails 8 앱 부트스트랩 + SQLite 멀티DB(WAL)
- Story 1.2: 인증 제너레이터 + 운영 2인 seed
- Story 1.3: Tailwind v3 핀 + DESIGN.md 토큰 이관
- Story 1.4: 앱 셸 — 좌측 내비 + 헤더
- Story 1.5: `config/scoring.yml` 튜닝값 자리 + 시크릿 격리

## Requirements & Constraints

- **스타터 규격** — Rails 8.x greenfield 신규 앱. 언어는 Ruby다(Python·Node 백엔드 코드 생성 금지). 스택은 SQLite 3.x / Solid Queue·Solid Cache(Rails 8 기본, SQLite 백엔드) / Tailwind CSS v3.x. Redis·Postgres·Sidekiq 없음.
- **동시성(NFR-2)** — 배치 쓰기 중 웹 읽기가 논블로킹이어야 한다. WAL + `busy_timeout 5000ms`, 단일 라이터 전제, queue/cache는 별도 DB 파일로 격리한다.
- **접근 보호** — 미인증 요청은 로그인으로 리다이렉트된다. 외부 공개 회원가입·멀티테넌시는 범위 밖(내부 도구).
- **정직성 원칙(NFR-7)** — 이후 화면이 불확실성을 숨기지 않도록, 위젯을 숨기지 않고 자리를 유지하는 정직성 상태 스타일이 DESIGN.md에 정의돼 있다. Epic 1은 토큰·셸만 세우지만 이 원칙을 깨는 구조를 만들지 않는다.
- **성능(NFR-4)** — 후속 요청 경로가 재계산하지 않도록, 무거운 파생값은 배치 물질화가 원칙이다. Epic 1에서 도입하는 설정·셸이 이 경계를 넘지 않는다.

## Technical Decisions

- **AD-12 멀티DB** — `config/database.yml`에 app·queue·cache 3개 SQLite 파일을 분리 정의한다. WAL + `busy_timeout 5000ms` 기본 적용, `bin/rails db:prepare` 통과가 완료 기준. `app.sqlite3`가 스냅샷 원천이므로 후속 에픽에서 일일 백업 대상이 된다(queue/cache 제외).
- **AD-14 인증** — `bin/rails generate authentication`이 만드는 `User`·세션·`has_secure_password`를 그대로 쓴다(직접 구현 금지). 운영 2인을 seed로 등록하고 목업 아바타 2인과 정합시킨다. 세션 기반, 커스텀 인증·JWT 도입 금지.
- **AD-15 디자인 토큰** — DESIGN.md의 Tailwind 매핑을 `config/tailwind.config.js`의 `theme.extend`로 그대로 이관한다. 원시 Tailwind 색(`blue-600`·`indigo-500` 등) 직접 사용 금지 — 정의된 토큰만 쓴다. 공유 위젯은 `app/views/shared/_*.html.erb` + `app/helpers`로 캡슐화하는 규약(후속 에픽 대비 구조만 존중).
- **Tailwind v3 핀(필수)** — `tailwindcss-rails` 기본이 4.x이므로 v3.x로 명시 핀한다. v4의 CSS `@theme` 문법은 쓰지 않고 `theme.extend` 관용구를 쓴다.
- **AD-4 scoring.yml** — 미확정 실측 튜닝값을 코드 상수로 하드코딩하지 않도록 `config/scoring.yml`에 키 자리를 만든다. 대상 키는 기준선 N·유사도 τ·기회 점수 가중치와 정규화 매핑·에버그린 나이/배수 임계·조회수 하한(고정값·k)·구독자 규모 임계·극단배수(25x)·위젯별 전환 스냅샷 수·`is_short` duration 임계. 값은 잠정 기본이되 코드는 이 파일에서만 읽는다(테스트가 하드코딩 회귀를 잡는다). 스파인은 자리만 고정하고 실제 값은 본개발 실측이다.
- **AR-Secrets** — API 키(YouTube·Gemini)는 Rails credentials 또는 ENV로만 두고 서비스 경계에서만 읽는다. 리포·코드에 키 하드코딩 금지(grep 검증).
- **데이터 규약(참조)** — 시간 경계는 `Asia/Tokyo` 고정, 시각 자체는 UTC datetime. Epic 1이 직접 모델을 만들진 않지만 앱 타임존 설정에 반영한다.

## UX & Interaction Patterns

- **좌측 내비 6항목** — 대시보드 / 인기 콘텐츠 / 경쟁 채널 / 콘텐츠 갭 / 저장한 영상 / 설정. 활성 항목은 `primary-600` 배경 + 흰 텍스트, 비활성은 뮤트, hover는 `primary-50`. 내비 폭 약 180px. 하단에 "데이터 범위(YouTube 전체: 한국어+일본어 시장)" 안내 박스. 각 항목은 빈 라우트로 연결하고 후속 에픽이 화면을 채운다.
- **헤더** — 제목 + 부제("다음 주 제작할 주제를 10분 안에 결정하세요") + 검색바 자리 + "오늘 업데이트" + 아바타 2인(운영 2인과 정합).
- **디자인 토큰 이관 대상** — primary `#1145DD`·success `#159C49`·캔버스/서피스/보더/텍스트/뱃지 색·radius(카드 12/컨트롤 8/칩 6)·spacing(4px 베이스). 폰트 스택 `Pretendard, "Noto Sans KR", "Noto Sans JP", system-ui …`(한·일 글리프 동시 커버), 숫자 `tabular-nums`. 타입 스케일(score/h1/h2/h3/nav/body/caption/label)과 그림자(card/cardHover/dropdown)도 함께 이관한다.
- **반응형** — 좌측 내비는 모바일에서 축소(햄버거 드로어 또는 아이콘 레일)되고, 본문(`body`)은 절대 가로 스크롤되지 않는다.
- **라벨 정합(강제)** — "구독자 대비 조회수"라는 표현은 어디에도 두지 않고 "성과 배수(채널 평소 대비)"로 통일한다. 한국어 문구는 마침표로 끝낸다.

## Cross-Story Dependencies

- Story 1.1(부트스트랩)이 스타터이며 의존이 없다. Story 1.2·1.3·1.5는 모두 1.1에 의존한다.
- Story 1.4(앱 셸)는 1.2(인증)와 1.3(토큰)에 함께 의존한다 — 로그인 뒤 렌더되고 토큰으로 스타일링되기 때문이다.
- 후속 에픽 전제 — Epic 2의 첫 모델·서비스 스토리들은 1.1(DB)·1.5(scoring.yml·시크릿)을 전제하고, Epic 6의 공유 표시 컴포넌트는 1.3(토큰)을 전제한다. Epic 7의 `SavedVideo`·저장 기능은 1.2의 `User`를 전제한다.
