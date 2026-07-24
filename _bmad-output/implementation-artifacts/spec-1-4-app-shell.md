---
title: 'Story 1.4: 앱 셸 — 좌측 내비 + 헤더'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
  - '{project-root}/DESIGN.md'
  - '{project-root}/CLAUDE.md'
warnings: []
baseline_revision: '6e1f71a59f503f9ce0bed77f4367932915d2e7c9'
final_revision: '9b0fed4be4ded22eced7649e6e8bb1af9231036e'
---

<intent-contract>

## Intent

**Problem:** 로그인 후 진입할 앱 셸(좌측 내비 + 헤더)이 없어 화면 간 이동·현재 위치 인지가 불가능하다. 후속 6개 화면 에픽이 얹힐 공통 셸이 필요하다.

**Approach:** DESIGN.md 토큰만으로 좌측 내비(6항목 + 활성 강조 + 데이터 범위 안내)와 헤더(제목·부제·검색바 자리·"오늘 업데이트"·아바타 2인)를 만든다. 셸은 인증된 화면에만 렌더(로그인 화면 제외)한다. 6개 내비 항목을 빈 placeholder 라우트로 연결(후속 에픽이 채운다). 모바일에서 내비가 축소되고 본문이 가로로 깨지지 않는다.

## Boundaries & Constraints

**Always:**
- 색·간격·radius·폰트는 DESIGN.md(§10 Tailwind 토큰)에서만. 원시 Tailwind 색(`blue-600` 등) 금지(test/design_tokens_test.rb가 가드).
- 좌측 내비 6항목 순서·라벨: 대시보드 / 인기 콘텐츠 / 경쟁 채널 / 콘텐츠 갭 / 저장한 영상 / 설정(§4.1·IA §11). 활성 항목은 `primary-600` 배경·흰 텍스트, 비활성 hover `primary-50`.
- 내비 하단에 데이터 범위 안내(YouTube 전체: 한국어+일본어 시장) — `surface-sunken`·`radius-card`·뮤트.
- 헤더: 제목("YouTube 콘텐츠 리서치")·부제("다음 주 제작할 주제를 10분 안에 결정하세요")·검색바 자리(§4.8, 비동작 placeholder)·"오늘 업데이트" outline 버튼·아바타 2인(원형).
- 셸은 인증 상태에서만 렌더(로그인·비밀번호 화면엔 셸 없음). head는 중복 정의하지 않는다.
- 모바일(`< md`)에서 좌측 내비가 축소(오버레이 드로어/토글)되고, 본문(`body`)은 가로 스크롤이 없다(§5). `min-w-0`·`overflow` 가드.
- 각 내비 항목은 인증된 빈 placeholder 라우트로 연결된다(후속 에픽이 채운다).
- 라벨 정합: 화면 어디에도 "구독자 대비 조회수" 없음 → "성과 배수(채널 평소 대비)"(§9, PRD §11). (셸엔 성과 배수 UI가 없지만 규칙 상속.)

**Block If:**
- (없음 — UI 셸, 외부 의존 없음.)

**Never:**
- 스코어링/수집/데이터 화면 콘텐츠 구현(각 6.x·7.x 소관). placeholder만.
- 검색 기능 로직(FR-25, Story 7.1). 검색바는 시각 자리만.
- 새 색·토큰 신설. 목업과 다르게 갈 지점은 임의 변경 말고 운영자에게(§0/§11).
- 실존 인물 사진 아바타 하드코딩(원형 이니셜/플레이스홀더로).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 인증 후 대시보드 | 유효 세션, GET `/` | 200, 좌측 내비 6항목 + 헤더 렌더, 대시보드 항목 활성 | — |
| 내비 이동 | GET `/popular` 등 6경로 | 각 200, 해당 항목 활성 강조 | — |
| 미인증 접근 | 세션 없음, GET `/` | 로그인 화면으로 리다이렉트(셸 없음) | — |
| 로그인 화면 | GET `/session/new` | 셸(내비/헤더) 렌더 안 됨 | — |
| 활성 표시 | 현재 경로 = competitors | competitors만 활성(primary), 나머지 비활성 | — |

</intent-contract>

## Code Map

- `config/routes.rb` -- root=dashboard#index + 6 내비 경로(popular/competitors/content_gap/saved/settings)
- `app/controllers/{dashboard,popular,competitors,content_gap,saved,settings}_controller.rb` -- 인증 상속 placeholder(#index)
- `app/controllers/home_controller.rb`·`app/views/home/` -- 제거(대시보드로 대체)
- `app/views/layouts/application.html.erb` -- `authenticated?` 게이트로 셸 렌더
- `app/views/layouts/_sidebar.html.erb`·`_header.html.erb` -- 셸 파셜(토큰 사용)
- `app/views/{dashboard,popular,…}/index.html.erb` -- 화면별 placeholder("준비 중 — 후속 에픽")
- `app/helpers/navigation_helper.rb` -- 활성 항목 판정 + 내비 항목 정의
- `app/javascript/controllers/*` -- 모바일 내비 토글(Stimulus, 최소)
- `test/integration/app_shell_test.rb` -- 내비 6항목·활성·헤더·인증 게이트 검증

## Tasks & Acceptance

**Execution:**
- [x] `config/routes.rb` + 6 컨트롤러 -- root를 `dashboard#index`로, `popular`·`competitors`·`content_gap`(경로 `/content-gap`)·`saved`·`settings` GET 라우트 + 인증 상속 placeholder 컨트롤러/뷰. `home` 컨트롤러·뷰 제거 -- 빈 라우트 연결 AC
- [x] `app/helpers/navigation_helper.rb` -- 내비 6항목(라벨·경로·아이콘) 정의 + `nav_active?`/활성 클래스 헬퍼(현재 컨트롤러·경로 기준) -- 활성 강조 AC
- [x] `app/views/layouts/_sidebar.html.erb` -- SPARTA 로고 + 6항목(활성 primary·hover primary-50, `text-nav`·`radius-control`) + 하단 데이터 범위 안내 박스. `nav-width` 180px, 우측 `border-default` -- §4.1 내비
- [x] `app/views/layouts/_header.html.erb` -- 제목·부제·검색바 자리(§4.8)·"오늘 업데이트" outline 버튼·아바타 2인(원형)·모바일 햄버거 토글 -- §4.8 헤더
- [x] `app/views/layouts/application.html.erb` -- `authenticated?`면 sidebar+header+`<main>`(yield), 아니면 bare yield. 본문 `overflow-x` 가드·`min-w-0` -- 셸 게이트·반응형 AC
- [x] `app/javascript/controllers/sidebar_controller.js`(Stimulus) -- 모바일 내비 드로어 토글(최소). 데스크톱은 상시 표시 -- 모바일 축소 AC
- [x] `test/integration/app_shell_test.rb` -- (1) 인증 후 `/` 및 6경로 200, (2) 6 내비 라벨 렌더, (3) 현재 경로 항목만 활성, (4) 헤더 제목·부제·"오늘 업데이트"·아바타 2인 존재, (5) 미인증 리다이렉트·로그인 화면 셸 부재 -- 검증

**Acceptance Criteria:**
- Given 로그인 상태, when 앱 셸이 렌더되면, then 좌측 내비에 6항목(대시보드/인기 콘텐츠/경쟁 채널/콘텐츠 갭/저장한 영상/설정)이 있고 활성 항목이 `primary-600`으로 강조된다.
- Given 내비, when 하단을 보면, then 데이터 범위(YouTube 전체: 한국어+일본어 시장) 안내가 있다.
- Given 헤더, when 렌더되면, then 제목·부제("다음 주 제작할 주제를 10분 안에 결정하세요")·검색바 자리·"오늘 업데이트"·아바타 2인이 있다.
- Given 모바일 화면, when 렌더되면, then 좌측 내비가 축소되고 본문이 가로로 깨지지 않는다.
- Given 각 내비 항목, when 클릭하면, then 인증된 빈 placeholder 라우트로 연결된다(후속 에픽이 채운다).
- Given 원시 Tailwind 색, when 스캔하면, then 셸 마크업에 직접 사용이 없다(토큰만).

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4: (high 0, medium 1, low 3)
- defer: 0
- reject: 6: (low 6)
- addressed_findings:
  - `[medium]` `[patch]` 모바일 드로어 a11y·버그 클러스터 — 리사이즈로 desktop↔mobile 왕복 시 stuck-open(실버그), Escape 미닫힘, 닫힘 상태 off-screen 링크 focusable, hamburger `aria-expanded` 없음. `sidebar_controller.js`에 matchMedia 리셋·Escape 핸들러·`inert`/`aria-hidden` 관리·포커스 이동, hamburger에 `aria-controls`/`aria-expanded`, aside에 `id` 추가.
  - `[low]` `[patch]` `application.html.erb` 콘텐츠 컬럼 `overflow-x-hidden`이 CSS 규칙상 `overflow-y:auto` 스크롤 컨테이너를 만들어 향후 sticky 요소의 함정 → 제거(body `overflow-x-hidden`·main `overflow-x-auto`·`min-w-0`로 이미 가드).
  - `[low]` `[patch]` `_header.html.erb` 제목·부제에 `break-keep` 추가(§7 한국어 어절 줄바꿈), `_sidebar` "자세히 보기 →" `href="#"`(스크롤 점프) → 비내비게이션 버튼.
  - `[low]` `[patch]` `app_shell_test.rb` 활성 배타성 dashboard/settings 2개만 → 6항목 전체 루프, 미인증 리다이렉트 `/`만 → 6경로 전체(컨트롤러명 오타 회귀·게이트 누락 포착).
- rejected(noise/미래·정확): body `overflow-x-hidden` 클립(셸 허용), 플레이스홀더 버튼 no-op(곧 후속 에픽 배선·목업 정합), 인증자 로그인화면 셸(경미 엣지·비누수), `authenticated?` respond_to 가드(YAGNI·현 컨트롤러 전부 상속), 네임스페이스 활성 판정(6 컨트롤러 top-level 정확), `w-[180px]`(§10에 width 토큰 없음·값은 §3.2 nav-width 180px 정확).

## Design Notes

**셸 렌더는 `authenticated?` 게이트로.** Rails 8 인증 제너레이터가 제공하는 헬퍼(`authenticated?`)로 application 레이아웃에서 분기 — 인증 화면(로그인/비밀번호)엔 셸이 안 붙고, head는 한 곳(레이아웃)에만 둔다. 별도 레이아웃 파일 없이 파셜 2개(sidebar/header)로 캡슐화.

**목업 정합(Planning/목업 샘플.png).** 좌상단 "SPARTA CONTENT LAB" 로고, 좌측 내비 활성 pill=대시보드, 헤더 우측에 검색바·"오늘 업데이트" outline 버튼·아바타 2인·`+` 원형 버튼. 시각은 목업 그대로, 라벨은 §9 방법론 문구.

**활성 판정.** 헬퍼가 현재 컨트롤러명으로 활성 항목을 판정(`controller_name`), 활성=`primary-600`/흰 텍스트, 비활성 hover=`primary-50`/`primary-600` 텍스트(§4.1).

**아바타.** 실사진 없으므로 원형 이니셜/플레이스홀더 2개(§4.5 원형 이니셜 아바타 톤). seed 운영자 수(2)와 정합.

**반응형은 CSS/Stimulus.** Minitest는 브라우저를 안 띄우므로 구조(햄버거 버튼 존재·sidebar 반응형 클래스·본문 overflow 가드) 렌더를 검증하고, 실제 드로어 동작은 시각 확인 영역으로 둔다.

## Verification

**Commands:**
- `bin/rails test test/integration/app_shell_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음, design_tokens 원시색 가드 포함)
- `bin/rails routes | grep -iE "dashboard|popular|competitors|content_gap|saved|settings"` -- expected: 6 경로 존재, root=dashboard#index
- `bin/rails tailwindcss:build` -- expected: 종료 0(셸 토큰 유틸 컴파일)
- 수동: 로그인 후 `/`·6경로에서 내비 활성·헤더·모바일 폭 축소 육안 확인(선택)

## Auto Run Result

Status: done

**구현 요약** — 인증된 화면에만 렌더되는 앱 셸을 DESIGN.md 토큰으로 구현. 좌측 내비 6항목(대시보드/인기 콘텐츠/경쟁 채널/콘텐츠 갭/저장한 영상/설정)·활성 primary 강조(aria-current)·하단 데이터 범위 안내, 헤더(제목·부제·검색바 자리·"오늘 업데이트"·아바타 2인·+ 버튼·모바일 햄버거). home#index placeholder를 dashboard#index로 대체하고 6개 화면 placeholder 라우트/컨트롤러 연결(후속 에픽이 채움). 모바일 오버레이 드로어(Stimulus), 본문 가로 스크롤 가드.

**변경 파일(주요)**
- `config/routes.rb`(root=dashboard + 6경로), 6 컨트롤러(dashboard/popular/competitors/content_gap/saved/settings) + placeholder 뷰
- `app/helpers/navigation_helper.rb` — 내비 6항목·활성 판정·토큰 클래스·아이콘 SVG
- `app/views/layouts/_sidebar.html.erb`·`_header.html.erb`·`application.html.erb`(authenticated? 게이트)
- `app/javascript/controllers/sidebar_controller.js` — 모바일 드로어(matchMedia 리셋·Escape·inert·aria)
- `test/integration/app_shell_test.rb` — 6경로 200·6항목 활성 배타성·헤더·데이터 범위·인증 게이트(7 tests/105 assertions)
- 제거: `home_controller.rb`·`app/views/home/`

**리뷰 결과** — Blind + Edge Case 병렬. 셸 기능·토큰 충실도·활성 로직 정확 확인. patch 4(드로어 a11y·overflow·§7·테스트 커버리지), reject 6(플레이스홀더·미래·정확 판정). intent_gap·bad_spec 0. 편차(authenticated? 헬퍼·아바타 이니셜·w-[180px]·Stimulus 자동 등록) 타당.

**검증** — Ruby 3.4.10 / Rails 8.1.3 / Tailwind v3.4.13. 37 runs, 316 assertions, 0 failures(1.1~1.3·원시색 가드 회귀 없음). 6 라우트+root=dashboard, home 완전 제거, tailwindcss:build 성공.

**잔여 리스크** — 모바일 드로어 동작(inert·focus·drawer 애니메이션)은 Minitest(무브라우저) 범위 밖이라 시각 확인 영역. 데스크톱 우선(§5) 내부 도구라 영향 제한적. 실제 화면 데이터·다국어 오버플로는 후속 콘텐츠 에픽에서 검증.
