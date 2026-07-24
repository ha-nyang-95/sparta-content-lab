---
title: 'Story 6.6: 에버그린 탭 — 후보 표시 + 검증 + 수집 중'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-1-shared-display-components.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-2-dashboard-home.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-3-popular-videos-table.md'
  - '{project-root}/DESIGN.md'
warnings: []
baseline_revision: 'd2a3b5d060e62e9b2526f18d929dae1d6252d675'
final_revision: ''
---

<intent-contract>

## Intent

**Problem:** 에버그린은 별도 화면이 아니라 대시보드·인기 콘텐츠 안의 콘텐츠다(FR-9 기간 탭). 6.3이 인기 콘텐츠에 에버그린 기간 탭(`evergreen_candidate` 필터)을 이미 넣었고 6.2가 대시보드에 에버그린 위젯 자리를 뒀지만, **후보 vs 검증** 정직성 구분(§4.7)이 아직 없다.

**Approach:** 물질화된 `VideoScore.evergreen_candidate`(3.4)를 읽어(AD-3) §4.7 정직성 2단계 뱃지를 공유 컴포넌트에 정본화한다 — **후보**(ghost: 후보지만 관측 부족·잠정) vs **검증**(solid: 관측 충분·확정). 승격 기준 = 후보 AND 프리로드 `daily_stats` 수 ≥ `cold_start_snapshots.evergreen_validation`(14, 스냅샷 카운트 게이트 — 스파크라인 콜드스타트와 동형, 재계산 아님). 인기 콘텐츠 에버그린 탭 행과 대시보드 에버그린 섹션이 이 뱃지를 소비한다.

## Boundaries & Constraints

**Always:**
- **읽기 전용**(AD-3) — `VideoScore.evergreen_candidate`(물질화, 3.4 DetermineEvergreen)와 프리로드 `daily_stats` 수만 읽는다. 나이·배수·지속성 **재계산 금지**. 후보/검증 승격은 스냅샷 **개수** 게이트일 뿐(관측 충분성 대용)이다.
- **후보 vs 검증 승격**(§4.7) — `evergreen_candidate=false` → 뱃지 없음(nil). `candidate=true AND daily_stats.size < evergreen_validation(14)` → `:evergreen_candidate`(ghost 뱃지 — 투명 배경·`success-100` 보더·`success-700` 텍스트·"에버그린 후보", 잠정). `candidate=true AND daily_stats.size >= 14` → `:evergreen_verified`(solid — `success-600` 배경·흰 텍스트·✓, 확정). **검증 스냅샷 부족이면 후보로 자리 유지**(위젯 숨김 금지).
- **공유 뱃지 정본화** — `ScoringDisplayHelper#evergreen_badge_status(score, video)` 가 위 3분기를 반환하고, 렌더는 기존 `shared/_honesty_status`(`:evergreen_candidate`/`:evergreen_verified` — 6.1이 §4.7로 못박음) 재사용. 원시 색·신규 팔레트 금지.
- **인기 콘텐츠 소비**(6.3) — 에버그린 탭(`@period == "evergreen"`)에서 `_video_row` 에 `evergreen: true` local 을 넘겨 제목 셀 인라인 칩 자리에 에버그린 뱃지 추가. 다른 기간 탭은 미표시(클러터 방지). 쿼리·정렬 불변(6.3 유지).
- **대시보드 소비**(6.2) — "에버그린 콘텐츠" 섹션에 후보/검증 컴팩트 리스트를 렌더. 컨트롤러가 `evergreen_candidate=true` 스코어를 읽기 전용 로드(배수 desc·프리로드). 후보 존재 시 리스트, 없으면 기존 "데이터 수집 중" 자리 유지(AD-7·§4.7).
- 색 **DESIGN §10 토큰만**(AD-15). 라벨 "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**. 상태 문구 Glossary 정합. 반응형(§5)·다국어(§7)·nil 방어(AD-9). N+1 프리로드 계약(`includes(video: [:channel, :daily_stats])`).

**Block If:**
- (없음 — §4.7 뱃지·evergreen_candidate 물질화·evergreen_validation 스냅샷 게이트로 확정. '지속성 재계산' 검증은 배치(Epic 3) 영역 — 이 표시 스토리 범위 밖, 스냅샷 카운트 대용으로 정직히 표기.)

**Never:**
- 웹 요청 경로에서 에버그린 나이·배수·지속성 재계산(물질화 flag + 스냅샷 개수만). 신규 `evergreen_verified` 컬럼·배치 추가(범위 밖). 원시 Tailwind 색. "구독자 대비 조회수". 후보를 검증으로 과대 표기(스냅샷 부족 시 반드시 후보). 값 없다고 에버그린 위젯 숨김. 다른 기간 탭에 에버그린 뱃지 남발.
- 6.3 인기 콘텐츠 쿼리/정렬/밴드 로직 변경. 콘텐츠 갭·설정(6.5·6.7) 기능.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 미후보 | evergreen_candidate=false | 뱃지 없음(nil) | — |
| 후보(관측부족) | candidate, daily_stats<14 | ghost "에버그린 후보" | — |
| 검증 | candidate, daily_stats>=14 | solid "✓ 에버그린" | — |
| score nil | video_score 없음 | 뱃지 없음 | AD-9 |
| daily_stats nil | 스냅샷 0 | <14 → 후보 | AD-9 |
| 인기 에버그린 탭 | period=evergreen | 행마다 뱃지(evergreen local) | — |
| 인기 타 탭 | period=1w 등 | 에버그린 뱃지 미표시 | — |
| 대시보드 섹션 | 후보 존재 | 컴팩트 리스트+뱃지 | — |
| 대시보드 콜드 | 후보 0 | "데이터 수집 중" 자리 | AD-7 |
| 읽기 전용 | GET | VideoScore 쓰기 없음 | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |
| 다국어 | 한·일 제목 | truncate·break-keep·title | §7 |
| N+1 | 리스트 | daily_stats·video_score 프리로드 | — |

</intent-contract>

## Code Map

- `app/helpers/scoring_display_helper.rb` -- (추가) `evergreen_badge_status(score, video)` → `:evergreen_verified`/`:evergreen_candidate`/nil. 프리로드 daily_stats·evergreen_validation 임계 읽기.
- `app/views/shared/_video_row.html.erb` -- (수정) 옵션 `evergreen` local — true & 후보면 제목 칩 자리에 `_honesty_status` 뱃지. 기본 false(타 탭 미표시).
- `app/views/popular/index.html.erb` -- (수정) 에버그린 탭에서 `_video_row` 에 `evergreen: (@period == "evergreen")` 전달. 에버그린 탭 empty 문구 정합(선택).
- `app/controllers/dashboard_controller.rb` -- (수정) `@evergreen_scores` 읽기 전용 로드(candidate·excluded 제외·배수 desc·limit·프리로드).
- `app/views/dashboard/index.html.erb` -- (수정) "에버그린 콘텐츠" 섹션: 후보 존재 시 컴팩트 리스트(뱃지), 없으면 기존 collecting 자리.
- `app/views/dashboard/_evergreen_item.html.erb` -- (신규) 컴팩트 행(제목 truncate + 에버그린 뱃지 + 성과 배수 pill). `_performance_cell` 재사용.
- `config/scoring.yml` -- `cold_start_snapshots.evergreen_validation`(기존, 14)
- `test/helpers/scoring_display_helper_test.rb`·`test/controllers/popular_controller_test.rb`·`test/controllers/dashboard_controller_test.rb` -- 뱃지 3분기·에버그린 탭 뱃지·대시보드 섹션·읽기 전용·라벨/색 금지·N+1

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/scoring_display_helper.rb` -- `evergreen_badge_status(score, video)`: `return nil unless score&.evergreen_candidate`; `threshold = Scoring::Config.fetch(:cold_start_snapshots, :evergreen_validation)`; `video.daily_stats.size >= threshold ? :evergreen_verified : :evergreen_candidate`. daily_stats 프리로드 전제(size 는 로드된 컬렉션 카운트, 재쿼리 금지) -- 헬퍼 AC
- [ ] `app/views/shared/_video_row.html.erb` -- `evergreen = local_assigns.fetch(:evergreen, false)`; 제목 아래 칩 flex 안에서 `<% if evergreen && (ev = evergreen_badge_status(score, video)) %><%= render "shared/honesty_status", status: ev %><% end %>`. 기본 false → 기존 소비처(6.3 타 탭·6.5 콘텐츠 갭) 무변화 -- 공유 행 AC
- [ ] `app/views/popular/index.html.erb` -- `_video_row` 렌더에 `evergreen: (@period == "evergreen")` local 추가(밴드/평면 두 경로 모두). 쿼리·정렬·컬럼 헤더 불변 -- 인기 소비 AC
- [ ] `app/controllers/dashboard_controller.rb` -- `@evergreen_scores = VideoScore.where(evergreen_candidate: true).joins(video: :channel).where(channels: { excluded: false }).includes(video: [:channel, :daily_stats]).order(performance_multiple: :desc).limit(5).to_a`(읽기 전용) -- 대시보드 로드 AC
- [ ] `app/views/dashboard/_evergreen_item.html.erb` -- local `score`: `video = score.video`; 제목(truncate·min-w-0·break-keep·title, §7) + `<%= render "shared/honesty_status", status: evergreen_badge_status(score, video) %>`(항상 후보/검증 — 리스트는 candidate 만) + `_performance_cell`(multiple: score.performance_multiple, view_count: nil, needs_verification: score.needs_verification) -- 컴팩트 행 AC
- [ ] `app/views/dashboard/index.html.erb` -- 에버그린 섹션: `<% if @evergreen_scores.any? %>` 리스트(`_evergreen_item` collection) `<% else %>` 기존 `honesty_status` collecting 자리. 위젯 숨김 금지 -- 대시보드 화면 AC
- [ ] `test/helpers/scoring_display_helper_test.rb`·`test/controllers/popular_controller_test.rb`·`test/controllers/dashboard_controller_test.rb` -- 뱃지 nil(미후보)/후보(<14)/검증(>=14)·score nil·인기 에버그린 탭 뱃지 표시·인기 1w 탭 미표시·대시보드 섹션 후보 렌더·대시보드 콜드 collecting·GET 읽기 전용·"구독자 대비 조회수" 부재·원시 색 부재·N+1 -- 검증

**Acceptance Criteria:**
- Given 물질화된 evergreen_candidate 와 프리로드 스냅샷, when 에버그린 뱃지를 판정하면, then 미후보=없음, 후보이며 스냅샷<14=에버그린 후보(ghost), 후보이며 스냅샷>=14=✓ 에버그린(solid)이다.
- Given 인기 콘텐츠 에버그린 탭, when 열면, then 각 행에 후보/검증 뱃지가 표시되고 다른 기간 탭에는 표시되지 않는다.
- Given 대시보드 에버그린 섹션, when 후보가 있으면 리스트+뱃지, 없으면 "데이터 수집 중" 자리가 유지된다(위젯 숨김 없음).
- Given 검증 스냅샷이 부족한 후보, when 렌더하면, then "검증"으로 과대 표기하지 않고 "후보"로 자리를 유지한다.
- Given GET 요청, when 처리하면, then VideoScore 를 쓰지 않는다(읽기 전용, AD-3).
- Given 좁은 화면·한일 혼재 제목, when 보면, then 뱃지가 자리를 지키고 제목이 말줄임되며 본문이 가로로 깨지지 않는다.

## Design Notes

**검증 = 스냅샷 개수 게이트(재계산 아님).** VideoScore 에 `evergreen_verified` 컬럼이 없고 AD-3가 웹 경로 재계산을 금하므로, 후보→검증 승격은 프리로드 `daily_stats` 개수 ≥ `cold_start_snapshots.evergreen_validation`(14)로 판정한다 — 스파크라인 콜드스타트(sparkline:7)와 동형의 관측 충분성 대용. "지속성까지 검증"(스냅샷들에 배수가 유지됐는지)은 배치가 `evergreen_verified` 를 물질화해야 하는 Epic 3 확장으로, 이 표시 스토리 범위 밖이며 스냅샷 개수로 정직히 근사한다.

**뱃지 렌더는 6.1 정본 재사용.** `shared/_honesty_status` 의 `:evergreen_candidate`(ghost) / `:evergreen_verified`(solid) 는 6.1이 §4.7로 못박았다 — 마크업 복제 없이 재사용. `_video_row` 뱃지는 `evergreen` local 로 게이트(기본 false)해 6.3 타 탭·6.5 콘텐츠 갭 소비처에 영향 없음.

**두 화면이 소비하되 게이트는 다르다.** 인기 에버그린 탭은 이미 `evergreen_candidate` 로 필터돼 전 행이 후보 → `evergreen: true` 로 뱃지 표시. 대시보드 섹션은 후보 존재 자체로 리스트를 켠다(전역 스냅샷 게이트가 아님 — 후보는 1일차부터 표시, 검증만 스냅샷 충족 시).

## Review Triage Log

이중 적대 리뷰(Blind Hunter + Edge Case Hunter). 두 리뷰어가 test DB에 쿼리 카운트를 실측하고 헤드라인 우려 대부분을 정상 확인, 한 지점에서 수렴.

**패치(적용)**
1. **[Med·정직성] 대시보드 에버그린 섹션 heading-only void** — `if 후보 있음 / elsif widget_collecting? / (else 없음)` → 스냅샷 ≥14일인데 자격 후보 0인 상태(수집됐으나 아무도 나이+배수 미충족)에서 헤더·캡션만 남고 본문이 빈 void → §4.7/AD-16 "위젯 숨김 금지·자리 유지" 위반. → `else` 추가("에버그린 후보가 아직 없습니다."). 회귀 테스트(14 distinct 스냅샷·후보 0) 추가.
2. **[Low] 대시보드 top-5 동점 비결정성** — `order(performance_multiple: :desc)` 타이브레이크 없음(ranked 규약과 불일치). → `order(video_id: :asc)` 추가.
3. **[Low] limit(5) 무언의 절단** — 6번째+ 후보가 안내 없이 드롭. → 후보 존재 시 "전체 보기 →"(인기 콘텐츠 에버그린 탭) 링크 추가로 절단 가시화.

**실증으로 기각(정상)**
- **읽기 전용(AD-3)** — @evergreen_scores 는 순수 SELECT, 헬퍼·파셜 읽기만. 쓰기 없음.
- **N+1** — 대시보드·인기 모두 `includes(video: [:channel, :daily_stats])` 프리로드 → `daily_stats.size` 는 로드된 컬렉션 카운트(쿼리 0). 반복 중 0 추가 쿼리 실측. evergreen_badge_status 소비처(대시보드 _evergreen_item·인기 evergreen 탭)는 전부 프리로드.
- **임계 경계** — size 13→후보, 14→검증(>=), 0→후보, nil score→nil. 정확.
- **_video_row 무회귀** — `local_assigns.fetch(:evergreen, false)` → 6.3 타 탭·6.5 콘텐츠 갭(evergreen local 미전달)은 뱃지 미표시. 뱃지는 `<a>` 안 비상호작용 `<span>`(기존 칩과 동일).
- **nil 배수 정렬·honesty_status nil 렌더·라벨/색 금지** — 전부 안전 실증.

**Defer(문서화)**
- **verified 라벨 "✓ 에버그린" vs Glossary "에버그린(검증)"** — 스펙 I/O 매트릭스가 "✓ 에버그린"을 명시하고 6.1 정본 파셜이라 미변경.
- **`.size` N+1 잠재(비프리로드 소비처)** — 현 3소비처 전부 프리로드라 미발생. 헬퍼 주석("daily_stats 프리로드 전제")이 계약 가드. 향후 소비처는 프리로드 필수.

**추가 테스트(회귀 방지)** — 대시보드 빈 상태 자리 유지 1건. 전 스위트 440 runs 0 failures.

## Verification

**Commands:**
- `bin/rails test test/helpers/scoring_display_helper_test.rb test/controllers/popular_controller_test.rb test/controllers/dashboard_controller_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/dashboard app/views/popular app/views/shared app/helpers/scoring_display_helper.rb` -- expected: 결과 없음
- `grep -rniE "(text|bg|border)-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-[0-9]" app/views/dashboard/_evergreen_item.html.erb app/helpers/scoring_display_helper.rb` -- expected: 원시 색 없음

## Auto Run Result

Status: done

- **구현**: `ScoringDisplayHelper#evergreen_badge_status`(미후보 nil / 후보<14스냅샷 ghost / >=14 solid — 스냅샷 개수 게이트, AD-3) 정본화. 인기 콘텐츠 에버그린 탭 행(`_video_row` evergreen local)·대시보드 에버그린 섹션(컴팩트 리스트 `_evergreen_item`)이 소비. 뱃지는 6.1 `_honesty_status`의 :evergreen_candidate/:evergreen_verified 재사용.
- **검증 승격 근거**: VideoScore에 evergreen_verified 컬럼 없음 + AD-3 웹 재계산 금지 → `cold_start_snapshots.evergreen_validation`(14) 스냅샷 개수로 관측 충분성 근사(스파크라인 콜드스타트와 동형). 지속성 검증은 배치(Epic 3) 확장 영역.
- **리뷰**: 이중 적대 리뷰 — 읽기전용·N+1·경계·무회귀 전부 실증 정상. 패치 3건(대시보드 void 자리 유지·top-5 타이브레이크·전체 보기 링크), 2건 defer.
- **테스트**: `bin/rails test` — **440 runs, 1498 assertions, 0 failures, 0 errors, 0 skips**(회귀 +1). grep — 금지 라벨·원시 팔레트 색 부재.
