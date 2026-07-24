---
title: 'Story 6.1: 공유 표시 컴포넌트 (배수 셀·정직성 상태·테이블 행·헬퍼)'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/DESIGN.md'
warnings: []
baseline_revision: '91354e9a6cfc004cd79d8b18c50e785d76350bc8'
final_revision: 'a22d8331eb2bae1860092304e686744de9bf67d3'
---

<intent-contract>

## Intent

**Problem:** 6화면이 서로 다른 세션에서 만들어지므로 성과 배수 표시·정직성 상태·영상 행을 각자 렌더하면 어긋난다. 공유 partial + helper로 캡슐화해 일관성을 강제해야 한다.

**Approach:** `ScoringDisplayHelper`(배수 밴드 클래스·라벨·편향 주석)와 `shared/_performance_cell`·`_honesty_status`·`_video_row` partial을 만든다. 값은 **배치 물질화 컬럼을 읽기만** 한다(재계산 없음, AD-3). 색·간격은 **DESIGN.md §10 토큰만**(AD-15, 원시 Tailwind 색 금지). 성과 배수 밴드는 §1.5 순차 그린 램프, 정직성 5상태는 §4.7 스타일(숨김 없이 자리 유지, AD-16), 다국어는 §7 오버플로 방어.

## Boundaries & Constraints

**Always:**
- 색·배경·radius·폰트는 **DESIGN.md §10 매핑 토큰만**(tailwind.config.js의 `mult`/`success`/`warning`/`badge`/`ink`/`surface`/`border`/`primary`, `rounded-card/control/chip`, `text-h2/h3/body/caption/label` 등). **원시 Tailwind 팔레트 색(blue-600·green-500 등) 직접 사용 금지**(AD-15, CLAUDE.md).
- `performance_band_class(multiple)`는 §1.5 순차 그린 램프를 매핑 — `<2배` 중립(`text-ink-muted font-normal`, 배경 없음) / `2~5배`(`bg-success-50 text-mult-good font-semibold`) / `5~10배`(`bg-success-100 text-mult-strong font-bold`) / `>10배`(`bg-mult-breakout text-white font-bold`). **amber·red 금지**(성과 배수에). 경계: <2, [2,5), [5,10], >10(DESIGN ">10배" 충실 — 10은 strong, 초과가 breakout).
- 표시 값은 물질화 컬럼을 **읽기만** — 성과 배수=`VideoScore.performance_multiple`, 자사 유사영상=`VideoScore.own_match_count`, 구독자 밴드=`Channel#subscriber_band`(3.3), 유형=`Video.is_short`. **웹 요청 경로 재계산·유사도·중앙값 금지**(AD-3).
- 정직성 5상태(`shared/_honesty_status`)를 §4.7 스타일로 — 데이터 수집 중(dashed 보더·`bg-app`·`text-ink-subtle`), 측정한계(neutral 칩 `bg-badge-neutralBg text-badge-neutralFg`), 에버그린 후보(ghost: 투명·`border-success-100 text-success-700`, "후보")·검증(solid `bg-success-600 text-white` ✓), 검증 요망(`bg-warning-50 text-warning-600 border-warning-500` ⚠), 저신뢰("저신뢰" `text-warning-600` + 툴팁). **값 없다고 위젯 숨기지 않는다**(자리 유지, AD-16).
- 제목·채널명 셀은 §7 다국어 방어 — `font-sans`(폰트 폴백), `break-keep`(word-break:keep-all), `line-clamp`/`truncate` + `title` 툴팁, `min-w-0`, `lang` 힌트. 한·일 혼재 오버플로 방어.
- 라벨 통일 — 성과 배수는 "**성과 배수(채널 평소 대비)**". "구독자 대비 조회수" 표현 어디에도 금지(PRD §11, CLAUDE.md). 성과 배수 옆/툴팁에 **두 편향 기전 명명** — (1) 누적 조회수 사용, (2) 최근 N개 젊은 기준선.
- nil 방어(AD-9): `performance_multiple` nil이면 "—"(밴드 없음), `own_match_count` nil/0이면 "없음", `published_at` nil이면 "미상". 예외 없이 렌더.

**Block If:**
- (없음 — DESIGN.md·목업이 토큰·컴포넌트 정의. 해석 갈리는 신규 디자인이면 운영자에 문의.)

**Never:**
- 원시 Tailwind 색 직접 사용(토큰만). 성과 배수에 amber/red. "구독자 대비 조회수" 문구. 웹 요청 경로 재계산(물질화 읽기만). 정직성 상태를 값 없다고 숨김. DESIGN.md에 없는 색·간격 발명(운영자 문의).
- ViewComponent 도입(스택 미채택 — partial + helper). 컨트롤러·라우트·화면 6개 구현(6.2~6.7). 데이터 계산.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 밴드 중립 | multiple 1.5 | text-ink-muted, 배경 없음 | — |
| 밴드 양호 | 3.0 | bg-success-50 text-mult-good | — |
| 밴드 강함 | 7.0 | bg-success-100 text-mult-strong | — |
| 밴드 경계 10 | 10.0 | strong(≤10) | — |
| 밴드 돌파 | 12.0 | bg-mult-breakout text-white | — |
| 배수 nil | multiple nil | "—", 밴드 없음, 예외 없음 | AD-9 |
| 성과 셀 라벨 | performance_cell | "성과 배수(채널 평소 대비)"·편향 2기전 | — |
| 정직성 수집중 | status collecting | dashed 보더·자리 유지 | — |
| 정직성 검증요망 | needs_verification | warning amber 플래그 | — |
| 정직성 저신뢰 | low_confidence | "저신뢰" text-warning-600 + 툴팁 | — |
| 영상 행 | video + score | 썸네일·제목(line-clamp)·채널·업로드일·조회수·배수·유사영상·유형·밴드 | — |
| 다국어 제목 | 한·일 혼재 긴 제목 | break-keep·line-clamp·title 툴팁·min-w-0·lang | — |
| 라벨 금지 | 전 컴포넌트 | "구독자 대비 조회수" 부재 | — |

</intent-contract>

## Code Map

- `app/helpers/scoring_display_helper.rb` -- `performance_band_class`·`performance_multiple_label`·`performance_bias_note`·`subscriber_band_label`·`video_type_label`
- `app/views/shared/_performance_cell.html.erb` -- 배수 히어로 셀(밴드)·raw 조회수 뮤트 2차·편향 툴팁
- `app/views/shared/_honesty_status.html.erb` -- 5상태 §4.7 렌더(status 로컬 분기)
- `app/views/shared/_video_row.html.erb` -- 급상승 영상 행(썸네일·제목·채널·업로드일·조회수·배수·유사영상·유형·밴드)
- `app/models/video_score.rb`·`channel.rb`·`video.rb` -- 읽기 소스(기존)
- `config/tailwind.config.js` -- §10 토큰(기존, 참조)
- `test/helpers/scoring_display_helper_test.rb`·`test/views/shared_components_test.rb` -- 밴드 경계·라벨·정직성·다국어·nil·라벨 금지

## Tasks & Acceptance

**Execution:**
- [x] `app/helpers/scoring_display_helper.rb` -- `performance_band_class(multiple)`(§1.5 램프, nil→중립); `performance_multiple_label`→"성과 배수(채널 평소 대비)"; `performance_bias_note`→"누적 조회수 사용·최근 N개 젊은 기준선" 두 기전; `subscriber_band_label(channel)`→`Scoring::SubscriberBand.label(channel.subscriber_count)`; `video_type_label(video)`→쇼츠/롱폼(is_short) -- 헬퍼 AC
- [x] `app/views/shared/_performance_cell.html.erb` -- 로컬 `multiple`·`view_count`·`needs_verification`. 배수를 `performance_band_class` 히어로 셀(tabular-nums), raw 조회수를 `text-ink-muted` 2차. 라벨·편향 툴팁(`title`). nil→"—" -- 배수 셀 AC
- [x] `app/views/shared/_honesty_status.html.erb` -- 로컬 `status`(:collecting/:measurement_limit/:evergreen_candidate/:evergreen_verified/:needs_verification/:low_confidence)·옵션 `detail`. §4.7 토큰 스타일로 분기 렌더(숨김 없이). 알 수 없는 status는 안전 무표시 -- 정직성 AC
- [x] `app/views/shared/_video_row.html.erb` -- 로컬 `video`(channel·video_score 접근). `<tr>` 셀: 썸네일(`img` 폴백)·제목(`break-keep line-clamp-2 min-w-0` + `title`/`lang`)·채널(truncate)·업로드일·조회수(tabular-nums)·`_performance_cell`·자사 유사영상(own_match_count "없음/N개")·`video_type_label` 배지·`subscriber_band_label`. nil 방어 -- 영상 행 AC
- [x] `test/helpers/scoring_display_helper_test.rb`·`test/views/shared_components_test.rb` -- I/O 매트릭스(밴드 경계 2/5/10/12·nil·라벨·편향·정직성 5상태 토큰·다국어 클래스·"구독자 대비 조회수" 부재) -- 검증

**Acceptance Criteria:**
- Given 물질화된 스코어링 값, when 공유 컴포넌트를 렌더하면, then `_performance_cell`이 성과 배수를 히어로 셀·색 밴드로, raw 조회수를 2차 뮤트로 표시한다.
- Given 성과 배수, when `performance_band_class`를 호출하면, then §1.5 순차 그린 램프(<2 중립/2~5/5~10/>10 solid)를 매핑하고 amber·red를 쓰지 않는다.
- Given 영상, when `_video_row`를 렌더하면, then 썸네일·제목·채널·업로드일·조회수·배수·자사 유사영상·유형 배지·구독자 밴드를 담는다.
- Given 정직성 상태, when `_honesty_status`를 렌더하면, then 5상태를 §4.7 토큰 스타일로 표시하고 위젯을 숨기지 않는다(자리 유지).
- Given 한·일 혼재 제목, when 제목 셀을 렌더하면, then 폰트 폴백·break-keep·line-clamp+title 툴팁·min-w-0·lang 힌트가 적용된다.
- Given 전 컴포넌트, when 렌더하면, then "구독자 대비 조회수"가 어디에도 없고 "성과 배수(채널 평소 대비)"로 통일되며 두 편향 기전이 명명된다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4: (high 0, medium 2, low 2)
- defer: 1: (low 1)
- reject: 6: (low 6)
- addressed_findings:
  - `[medium]` `[patch]` `_performance_cell` 밴드는 raw float로 계산하는데 표시는 `%.1f` 반올림 → 1.96이 "2.0×"인데 neutral 밴드(색·숫자 불일치). `multiple&.round(1)` 1회로 밴드·표시를 같은 값에서 구동 + 일관성 테스트 2건.
  - `[medium]` `[patch]` `_video_row` 제목에 `lang="ja"` 하드코딩 → 한·일 혼재에서 KR 제목을 JP로 오표시(스크린리더 오독). 제거(§7 방어는 폰트 폴백·break-keep·line-clamp·min-w-0·title 로 충족).
  - `[low]` `[patch]` `_video_row` N+1 유발(행마다 video_score·channel 조회) — 소비 화면이 `includes(:video_score, :channel)` 프리로드하도록 헤더 주석 명시(계약).
  - `[low]` `[patch]` `_performance_cell` 외부 div + 값 span aria-label 이중(이중 낭독) — 외부 div aria-label 제거, 값 span만 유지.
- deferred: per-title 언어 감지(제목별 lang 힌트) — 현재 한·일 혼재 판별 불가라 단일 lang 은 유해. 향후 감지 도입 시 lang 재부착.
- rejected(noise): honesty else 폴백(스펙 '안전 무표시'·잘못된 심볼은 dev 오류이지 데이터 부재 아님·AD-16은 데이터 부재 5상태 커버), has_one dependent(영상 삭제 경로 없음·표시 스토리 범위 밖), 채널 빈 title 속성(cosmetic·무해), 대형 배수 천단위 구분자(cosmetic·× 포맷), 날짜 타임존(앱 Asia/Tokyo 규약 정합), 제목 max-width(소비 화면 table-fixed·overflow-x-auto가 병리적 토큰 격리·AC가 테이블 가로스크롤 허용).

## Design Notes

**밴드 매핑(§1.5 충실).** `<2배` 중립(강조 안 함)·`2~5배` good·`5~10배` strong·`>10배` breakout(solid). 경계는 DESIGN "5~10배/>10배"에 맞춰 10은 strong, 초과가 breakout. 색은 tailwind 토큰(`text-mult-good`=#15803D, `bg-success-50/100`, `bg-mult-breakout`=#159C49). amber/red는 성과 배수에 금지 — 그 색은 정직성 경고·갭 뱃지 전용(빨강=나쁨 오독 방지). `>25배`는 밴드 위에 검증 요망 amber 플래그를 별도 축으로 겹친다(§4.7, `_honesty_status` needs_verification).

**읽기 전용(AD-3).** 컴포넌트는 물질화 컬럼만 읽는다 — `performance_multiple`·`own_match_count`·`subscriber_band`(config 임계 계산은 순수 함수라 요청 경로 허용). 유사도·중앙값·임베딩은 웹 요청 경로에서 계산하지 않는다. nil은 상태로 표시(—/없음/미상), 숨기지 않는다.

**다국어(§7).** 제목·채널명 셀은 `font-sans`(Pretendard→Noto KR→Noto JP 폴백), `break-keep`, `line-clamp-2`/`truncate` + `title` 전체 툴팁, `min-w-0`(flex 오버플로 방어), `lang` 힌트. 한·일 혼재 긴 제목이 레이아웃을 깨지 않게.

**정직성(§4.7·AD-16).** 5상태를 정식 토큰으로만 렌더해 나머지 UI와 한 몸으로. 값 없음/불확실을 디자인의 일부로 노출(숨김 금지). 후보(ghost)와 검증(solid)의 확신도 차이를 시각화.

## Verification

**Commands:**
- `bin/rails test test/helpers/scoring_display_helper_test.rb test/views/shared_components_test.rb` -- expected: 전부 통과
- `bin/rails test test/design_tokens_test.rb` -- expected: 토큰 회귀 없음
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/` -- expected: 결과 없음
- `grep -rniE "blue-[0-9]|green-[0-9]|red-[0-9]|amber-[0-9]" app/views/shared app/helpers/scoring_display_helper.rb` -- expected: 원시 색 없음(토큰만)

## Auto Run Result

Status: done

**구현 요약** — 6화면 공유 표시 컴포넌트를 partial + helper로 캡슐화(ViewComponent 미채택). `ScoringDisplayHelper`(성과 배수 §1.5 밴드 클래스·"성과 배수(채널 평소 대비)" 라벨·두 편향 기전 주석·구독자 밴드/유형 라벨), `shared/_performance_cell`(밴드 pill·raw 조회수 2차·반올림 일관·편향 툴팁), `_honesty_status`(§4.7 6상태·숨김 없이 자리 유지), `_video_row`(썸네일·제목 다국어 방어·채널·업로드일·조회수·배수·자사 유사영상·유형·구독자 밴드). 색은 DESIGN.md §10 토큰만(원시 팔레트 색 0), 물질화 값 읽기만(AD-3), nil 방어(AD-9).

**변경/신규 파일**
- `app/helpers/scoring_display_helper.rb`(신규)·`app/views/shared/_performance_cell.html.erb`·`_honesty_status.html.erb`·`_video_row.html.erb`(신규)
- `app/models/video.rb`(has_one :video_score)
- `test/helpers/scoring_display_helper_test.rb`·`test/views/shared_components_test.rb`(신규)

**리뷰 결과** — Blind + Edge Case 병렬. patch 4(밴드/표시 반올림 일관·lang 하드코딩 제거·N+1 프리로드 계약 주석·aria 중복 제거), defer 1(per-title lang 감지), reject 6(honesty else·has_one dependent·빈 title·구분자·타임존·제목 max-width — 스펙/규약/cosmetic/소비화면 격리). intent_gap·bad_spec 0. UI 정합·a11y 개선이라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 관련 28 runs/210 assertions, 전체 357 runs/1243 assertions, 0 failures(회귀 없음·design_tokens 그린). 밴드 경계 2/5/10/12·nil·반올림 일관(1.96→2.0× good)·라벨·편향·정직성 6상태 토큰·다국어 클래스·"구독자 대비 조회수" 부재·원시 색 부재 검증. `proposal.html`·`config/tailwind.config.js` 미변경.

**잔여** — 6화면 실제 구현(6.2 대시보드~6.7 설정)이 이 공유 컴포넌트를 `includes(:video_score, :channel)` 프리로드로 소비. per-title lang 감지 deferred. Epic 6 표시는 물질화 값 읽기만.
