---
title: 'Story 1.3: Tailwind v3 핀 + DESIGN.md §10 토큰 이관'
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
baseline_revision: '05260e241340fe33e5bfe07877bc246152fb8b7e'
final_revision: '844656cfd08fe8d511493d59ed567f9564792970'
---

<intent-contract>

## Intent

**Problem:** 6개 화면이 서로 다른 세션에서 만들어지므로 색·간격·radius를 세션마다 추정하면 어긋난다(AD-15). Tailwind가 없고, 있더라도 `tailwindcss-rails` 기본은 v4라 아키텍처가 지정한 v3 `theme.extend` 관용구와 어긋난다.

**Approach:** Tailwind를 **v3.x로 핀**(`tailwindcss-rails ~> 2.x`가 Tailwind v3 CLI 번들)하고, `DESIGN.md §10`의 `theme.extend` 매핑을 `config/tailwind.config.js`에 **verbatim 이관**한다. DESIGN.md가 값의 단일 원천이다. 폰트 스택·`tabular-nums`가 적용되고, 원시 Tailwind 색 직접 사용 금지 규칙을 문서화·가드한다.

## Boundaries & Constraints

**Always:**
- Tailwind는 **v3.x**로 핀된다(기본 v4 방지). v4 CSS `@theme` 미사용 — v3 JS `config/tailwind.config.js` + `theme.extend`.
- `theme.extend`의 색·fontFamily·fontSize·borderRadius·boxShadow는 **DESIGN.md §10 골든 그대로**(값 임의 변경·추가 금지). DESIGN.md가 원천, 충돌 시 DESIGN.md가 이긴다.
- 폰트 스택(`Pretendard, Noto Sans KR, Noto Sans JP, system-ui, …`)이 config에 설정되고 앱 본문(`font-sans`)에 적용된다. 숫자용 `tabular-nums`(Tailwind 내장 유틸)가 사용 가능하다.
- 원시 Tailwind 색(`blue-600`·`indigo-500`·`green-600` 등) 직접 사용 금지 — 규칙을 config 주석에 남기고 테스트로 가드(CLAUDE.md·DESIGN.md §11 상속).
- Tailwind 빌드(`tailwindcss:build`)가 성공하고 토큰 유틸(`bg-primary-600` 등)이 실제 값(#1145DD)으로 컴파일된다.

**Block If:**
- Tailwind v3를 번들하는 `tailwindcss-rails` 버전이 Rails 8.1/Ruby 3.4에서 설치·빌드 실패하는 경우 → HALT(blocking: `tailwind v3 툴체인 비호환`).

**Never:**
- 원시 Tailwind 색·radius·폰트를 화면에 직접 도입(토큰만).
- DESIGN.md §10에 없는 색·토큰 신설, 값 변경.
- 앱 셸·좌측 내비·헤더·컴포넌트 마크업(Story 1.4·6.x 소관). 이 스토리는 토큰 인프라 + 최소 적용까지.
- 스코어링/수집 코드.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| v3 핀 | 설치 후 | 번들 Tailwind CLI 버전이 `3.x`, gem은 2.x 라인 | 4.x면 실패 |
| 토큰 이관 | config 파싱 | primary-600=#1145DD·success-600=#159C49·radius card=12px·font Pretendard 등 §10 값 존재 | 누락 시 테스트 실패 |
| 빌드 컴파일 | `bg-primary-600` 사용면 | 빌드 CSS에 `#1145dd`(또는 #1145DD) 포함 | 없으면 실패 |
| 원시 색 사용 | app/views 스캔 | 금지 팔레트(blue/indigo/green/red/amber…-숫자) 직접 사용 없음 | 발견 시 실패 |

</intent-contract>

## Code Map

- `Gemfile`·`Gemfile.lock` -- `tailwindcss-rails ~> 2.x`(Tailwind v3 번들)
- `config/tailwind.config.js` -- DESIGN.md §10 `theme.extend` 이관의 단일 소재지 + content 경로 + plugins
- `app/assets/stylesheets/application.tailwind.css` -- `@tailwind` 지시어 + base 레이어(font-sans 적용)
- `app/assets/builds/tailwind.css` -- 빌드 산출(gitignore 대상, 커밋 안 함)
- `app/views/layouts/application.html.erb` -- 빌드된 tailwind 스타일시트 링크(제너레이터가 배선)
- `test/design_tokens_test.rb` -- 토큰 이관·v3 핀·원시색 금지 가드

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile` -- `gem "tailwindcss-rails", "~> 2.7"` 추가 후 `bundle install`, `bin/rails tailwindcss:install` 실행 -- v3 CLI·config·application.tailwind.css·레이아웃 배선 생성. 번들 CLI가 v3.x인지 확인
- [x] `config/tailwind.config.js` -- 제너레이터 기본 `theme.extend`를 **DESIGN.md §10 골든으로 교체**(colors primary/success/warning/mult/badge/app/surface/border/ink, fontFamily.sans, fontSize score~label, borderRadius card/control/chip, boxShadow card/cardHover/dropdown). content 경로·plugins는 유지. 상단에 "값 원천=DESIGN.md, 원시 색 금지" 주석 -- 토큰 이관 AC
- [x] `app/assets/stylesheets/application.tailwind.css` -- `@layer base`에서 본문에 `font-sans` 적용(폰트 스택 활성화). 과한 셸 스타일 금지(1.4 소관) -- 폰트 적용 AC
- [x] `test/design_tokens_test.rb` -- (1) config에 §10 핵심 토큰 값 존재, (2) tailwindcss-rails 2.x·번들 Tailwind v3 핀, (3) `bg-primary-600`이 빌드 시 #1145DD로 컴파일, (4) app/views에 원시 Tailwind 색 없음 -- 가드
- [x] `.gitignore` -- `app/assets/builds/*`(tailwind 빌드 산출)가 무시되는지 확인/추가 -- 산출물 미커밋

**Acceptance Criteria:**
- Given `tailwindcss-rails` 설치, when 버전을 확인하면, then Tailwind는 v3.x로 핀되고 v4 `@theme`을 쓰지 않는다.
- Given `config/tailwind.config.js`, when `theme.extend`를 보면, then DESIGN.md §10 토큰(primary #1145DD·success #159C49·warning·mult·badge·app/surface/border/ink·fontFamily·fontSize·radius 12/8/6·boxShadow)이 그대로 존재한다.
- Given 앱, when 렌더하면, then 폰트 스택 `Pretendard, Noto Sans KR, Noto Sans JP, system-ui`가 본문에 적용되고 `tabular-nums`가 사용 가능하다.
- Given app/views, when 원시 Tailwind 색을 grep하면, then 직접 사용이 없고 규칙이 문서화돼 있다.
- Given `bin/rails tailwindcss:build`, when 빌드하면, then 성공하고 사용된 토큰 유틸이 §10 값으로 컴파일된다.

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3: (high 0, medium 3, low 0)
- defer: 0
- reject: 3: (low 3)
- addressed_findings:
  - `[medium]` `[patch]` `test/design_tokens_test.rb` 토큰 가드(a)가 "verbatim"이라면서 ~40개 §10 값 중 8개만 검증 → 나머지 침묵 드리프트 허용. 전 색 hex(warning·badge·mult·app/surface/border/ink·전 스케일)·fontSize size+weight·boxShadow 전부 단언으로 강화(28→106 assertions).
  - `[medium]` `[patch]` `test/design_tokens_test.rb` 원시색 가드(d)가 `app/views/*.erb`만 스캔했으나 config content는 `app/helpers/*.rb`(§10 performance_band_class가 헬퍼)·js·다른 확장자 포함 → 스캔 범위를 content glob에 맞춰 확대 + 임의 hex(`bg-[#...]`)·추가 유틸 prefix(fill/stroke/divide/… ) 탐지.
  - `[medium]` `[patch]` `test/design_tokens_test.rb` 컴파일 테스트(c)가 home 뷰의 `text-primary-600`에 의존 → Story 1.4가 home 교체 시 JIT purge로 오탐(크로스-스토리 타임밤). 내구성 프로브 partial(`app/views/shared/_tailwind_token_probe.html.erb`)로 앵커 디커플 + `Dir.chdir` 대신 thread-safe `system(chdir:)`.
- rejected(noise/stock): 제너레이터 기본 플러그인(forms/typography/container-queries — forms는 폼 UI에 유용, inert), `~> 2.7` floor 핀(v4 차단하는 올바른 제약, 보안 패치 허용), 스타일시트 링크 순서(관용구·application.css 현재 비어 무충돌).

## Design Notes

**값 원천은 DESIGN.md §10의 `theme.extend` 블록이다 — 그대로 옮긴다(중복 정의로 드리프트 만들지 말 것).** 구현자는 DESIGN.md §10을 읽어 `colors/fontFamily/fontSize/borderRadius/boxShadow`를 verbatim 이관한다. 성과 배수 밴드(§1.5)는 `mult` 색 + 헬퍼(`performance_band_class`)로 매핑되는데, 헬퍼 자체는 공유 위젯 스토리(6.1) 소관이므로 여기서는 `mult` 색 토큰만 둔다.

**폰트 파일 self-host는 이 스토리 범위 밖(defer).** §2.1은 Noto Sans KR/JP self-host를 권하지만 실제 woff2 번들은 무거운 에셋 작업이다. 이 스토리는 스택 설정 + `font-sans` 적용까지. 스택에 이미 `system-ui`·`Hiragino Kaku Gothic ProN`·`Yu Gothic`·`Meiryo`가 있어 KR/JP 글리프는 시스템 폰트로 폴백된다. Pretendard/Noto 번들은 `deferred-work.md`에 남긴다.

**v3 핀 근거** — `tailwindcss-rails` 3.x+는 Tailwind v4를 번들한다. 2.x 라인(예 `~> 2.7`)이 Tailwind v3.4 CLI를 번들하므로 이걸 쓴다. 정확한 서브버전·빌드 배선은 제너레이터에 맡기고, 번들 CLI 버전이 3.x인지 실행으로 확인한다.

## Verification

**Commands:**
- `bundle show tailwindcss-rails` 또는 `grep tailwindcss-rails Gemfile.lock` -- expected: 2.x
- `bin/rails tailwindcss:build` -- expected: 종료 0, `app/assets/builds/tailwind.css` 생성
- config 토큰 grep -- expected: `#1145DD`·`#159C49`·`card:'12px'`·`Pretendard` 존재
- `bin/rails test test/design_tokens_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- app/views 원시색 grep -- expected: 매치 없음

## Auto Run Result

Status: done

**구현 요약** — Tailwind를 `tailwindcss-rails ~> 2.7`(번들 Tailwind CLI v3.4.13)로 v3 핀하고, DESIGN.md §10 `theme.extend`(colors·fontFamily·fontSize·borderRadius·boxShadow)를 `config/tailwind.config.js`에 **byte-identical verbatim** 이관. 본문에 `font-sans` 적용, 원시 Tailwind 색 금지 규칙 문서화·테스트 가드. v4 `@theme` 미사용.

**변경 파일(주요)**
- `config/tailwind.config.js` — §10 토큰 verbatim(단일 원천 주석)
- `app/assets/stylesheets/application.tailwind.css` — `@layer base { body { @apply font-sans } }`
- `app/views/shared/_tailwind_token_probe.html.erb` — 토큰 컴파일 회귀 방지 내구성 프로브(뷰 교체에 안 깨짐)
- `test/design_tokens_test.rb` — §10 전 값 검증·v3 핀·컴파일·원시색 금지(4 tests/106 assertions)
- `app/views/layouts/application.html.erb`(tailwind 링크)·`app/views/home/index.html.erb`(text-primary-600)·`.gitignore`(builds 무시)
- 그 외 제너레이터 stock(bin/dev·Procfile.dev·application.tailwind scaffold)

**리뷰 결과** — Blind + Edge Case 병렬. 이관 fidelity **byte-identical 확인**. patch 3(전부 테스트 가드 강화·크로스-스토리 타임밤 제거), reject 3(제너레이터 기본 플러그인·floor 핀·스타일시트 순서). intent_gap·bad_spec 0. 편차(Inter 제거·셸 마크업 1.4 보류·hex→rgb) 검증상 타당.

**검증** — Ruby 3.4.10 / Rails 8.1.3 / Tailwind v3.4.13. 30 runs, 211 assertions, 0 failures(1.1·1.2 회귀 없음). `tailwindcss:build` 성공, `bg-primary-600`→rgb(17 69 221)=#1145DD 컴파일. builds gitignore, 원시색 없음.

**잔여 리스크** — 폰트 파일 self-host 미구현(시스템 폴백 의존, deferred-work 기록). application.css는 tailwind 뒤 로드 — 1.4+ 커스텀 CSS는 cascade 인지 필요.
