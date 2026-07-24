---
title: 'Story 6.3: 인기 콘텐츠 — 급상승 영상 테이블 + 스파크라인'
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
  - '{project-root}/DESIGN.md'
warnings: []
baseline_revision: 'bc5e9627df172f17d202476a52c59893e0048982'
final_revision: '708da6d88e3fc7f2add223c7c9828ae34272d780'
---

<intent-contract>

## Intent

**Problem:** 운영자가 성과 배수 상위 영상을 탐색할 급상승 테이블이 없다(placeholder). 또 6.2가 미룬 필터(기간·카테고리·유형)의 실제 테이블 적용이 없다.

**Approach:** `PopularController#index`(얇게, 물질화 값 읽기만)가 `VideoScore.ranked`(성과 배수 desc)를 필터·프리로드해 로드하고, 인기 콘텐츠 화면이 §4.3 급상승 테이블(# / 영상 / 채널 / 업로드일 / 조회수 / 성과 배수 / 트렌드 스파크라인 / 자사 유사영상)을 렌더한다. 공유 `shared/_video_row`를 §4.3 정본으로 정렬(순번·인라인 유형/밴드/주제 칩·자사 유사 §1.4 뱃지·스파크라인 셀). 구독자 밴드 그룹핑 + 평면 토글, 6.2 필터 적용. 스파크라인은 저장된 일별 조회수 읽기만(재계산 없음, 콜드스타트 자리 유지 AD-7). DESIGN §10 토큰만.

## Boundaries & Constraints

**Always:**
- 컨트롤러 얇게 — `VideoScore.ranked`(성과 배수 desc·rank_eligible)를 필터·정렬·프리로드만. **재계산·유사도·중앙값 금지**(AD-3). `includes(video: [:channel, :daily_stats])`로 N+1 방지. 성과 배수·자사 유사=물질화 컬럼(`performance_multiple`·`own_match_count`) 읽기.
- 색·간격은 **DESIGN §10 토큰만**(원시 색 금지, AD-15). 테이블 §4.3, 뱃지 §4.4/§1.4, 밴드 §1.5, 스켈레톤 §6. 라벨 "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**.
- `shared/_video_row`를 §4.3 정본으로 정렬 — 컬럼: **#(순번, 옵션 local)** / 영상(썸네일 16:9 rounded-chip + 제목 truncate·min-w-0·title·break-keep, **유형·구독자 밴드·주제 힌트 인라인 칩**) / 채널(truncate) / 업로드일 / **조회수(뮤트 2차)** / **성과 배수(히어로 §1.5 밴드)** / **트렌드(스파크라인 셀, 옵션)** / **자사 유사영상(§1.4 뱃지 — 없음 neutral·1개 caution·2개+ danger)**. 영상 클릭 시 유튜브 URL(`https://www.youtube.com/watch?v=<youtube_video_id>`) 이동.
- 스파크라인(트렌드, 최근 7일) — `VideoDailyStat`(preload) view_count 시계열을 **읽기만** 인라인 SVG polyline(`stroke text-primary-600` 계열 토큰). 스냅샷 수 < `cold_start_snapshots.sparkline`(config)면 §4.7 "데이터 수집 중" 플레이스홀더로 **자리 유지**(위젯별, AD-7). 재계산 금지.
- **6.2 필터 실현**: 기간(1w/1m/3m = `published_at >= N일전`, evergreen = `evergreen_candidate: true`)·카테고리(`channels.category`)·유형(`is_short` long/short)을 Video 스코프에 적용(DashboardHelper 화이트리스트 파라미터 재사용). excluded 채널 제외. 밴드 그룹핑↔평면 토글(파라미터) — band면 `Channel#subscriber_band`로 그룹핑, 밴드 내 성과 배수 desc.
- 반응형(§5): 테이블은 `overflow-x-auto` 컨테이너 안에서 가로 스크롤, **본문 가로 스크롤 금지**. 제목 §7 다국어 말줄임.
- empty(조건 부합 영상 0 → empty 상태)·loading(스켈레톤 pulse)·error 상태. nil 방어(AD-9).

**Block If:**
- (없음 — §4.3·목업·6.1이 정의. 신규 디자인이면 운영자 문의.)

**Never:**
- 웹 요청 경로 재계산(물질화·저장 스냅샷 읽기만). 원시 Tailwind 색. "구독자 대비 조회수". 성과 배수에 amber/red. raw 조회수 기본 정렬(성과 배수 desc). 위젯 숨김(콜드스타트 자리 유지). 쇼츠/롱폼 혼합 배지.
- 컨트롤러에 계산 로직. 경쟁 채널 리스트·도넛·에버그린 카드(6.4~6.6).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 정렬 | ranked scope | 성과 배수 desc, id 타이브레이크 | — |
| 밴드 그룹핑 | layout=band | 구독자 밴드별 그룹·내부 배수 desc | — |
| 평면 | layout=flat | 단일 배수 desc 목록 | — |
| 기간 필터 | period=1w | published_at ≥ 7일전 | — |
| 에버그린 탭 | period=evergreen | evergreen_candidate 만 | — |
| 카테고리 | category=한국어교육일반 | 그 category 채널만 | — |
| 유형 | type=short | is_short=true 만 | — |
| 스파크라인 콜드 | 스냅샷<임계 | "데이터 수집 중" 자리 | AD-7 |
| 스파크라인 렌더 | 스냅샷≥임계 | SVG polyline(primary) | — |
| 자사 유사 뱃지 | own 0/1/2+ | neutral/caution/danger 뱃지 | — |
| 배수 밴드 | 12배 | breakout solid | — |
| 검증 요망 | needs_verification | ⚠ 검증 요망(§4.7) | — |
| 영상 링크 | 행 클릭 | youtube.com/watch?v=id | — |
| empty | 부합 영상 0 | empty 상태 | — |
| 모바일 | 좁은 뷰포트 | 테이블 가로 스크롤, 본문 스크롤 없음 | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |

</intent-contract>

## Code Map

- `app/controllers/popular_controller.rb` -- `#index` 얇게 — ranked 필터·프리로드·밴드 그룹핑(읽기만)
- `app/views/popular/index.html.erb` -- 인기 콘텐츠(placeholder 교체) — 필터 바 + §4.3 테이블(밴드 그룹/평면)·상태
- `app/views/shared/_video_row.html.erb` -- §4.3 정본 정렬(순번·인라인 칩·자사 유사 뱃지·스파크라인 셀)
- `app/helpers/scoring_display_helper.rb` -- `own_match_badge(count)`(§1.4)·`video_sparkline_points(video)`(daily_stats 읽기)·`youtube_watch_url(video)`
- `app/views/dashboard/_period_tabs.html.erb`·`_filter_bar.html.erb` -- `base_path` local 추가(popular 재사용)
- `app/helpers/dashboard_helper.rb` -- 필터 화이트리스트 재사용 + Video 스코프 변환 헬퍼
- `config/scoring.yml` -- `cold_start_snapshots.sparkline`(기존)
- `test/controllers/popular_controller_test.rb`·`test/views/popular_view_test.rb`·`test/views/shared_components_test.rb`(정렬 반영) -- 정렬·필터·밴드·스파크라인·뱃지·라벨 금지

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/scoring_display_helper.rb` -- `own_match_badge(count)` → {label, class} (0/nil "없음" `bg-badge-neutralBg text-badge-neutralFg`; 1 "1개" `bg-badge-cautionBg text-badge-cautionFg`; ≥2 "N개" `bg-badge-dangerBg text-badge-dangerFg`); `video_sparkline_points(video)` → 최근 7 `daily_stats`(preload) view_count 정규화 좌표 배열 또는 nil(스냅샷<임계); `youtube_watch_url(video)` → watch URL -- 헬퍼 AC
- [ ] `app/views/shared/_video_row.html.erb` -- §4.3 정본 정렬: 옵션 `rank` 선두 셀, 영상 셀에 유형·밴드·주제 힌트 인라인 칩, 조회수 뮤트, `_performance_cell` 히어로, 옵션 `sparkline`(SVG or 콜드 자리), 자사 유사 `own_match_badge`. 영상 클릭 youtube URL -- 정본 행 AC
- [ ] `app/controllers/popular_controller.rb` -- `#index`: `scope = VideoScore.ranked.joins(video: :channel).where(channels: {excluded: false})`; DashboardHelper 파라미터로 기간(published_at/evergreen)·카테고리·유형 where 적용; `@scores = scope.includes(video: [:channel, :daily_stats])`; layout=band면 `group_by { |s| s.video.channel.subscriber_band }`; `@period/@category/@type/@layout` 화이트리스트. **계산 없음** -- 얇은 컨트롤러 AC
- [ ] `app/views/popular/index.html.erb` -- placeholder 교체: 필터 바(`_period_tabs`/`_filter_bar` base_path=popular_path) → §4.3 테이블(`overflow-x-auto`, 밴드 그룹 헤더 or 평면, `_video_row` rank·sparkline) → empty/loading/error 상태. DESIGN §10 토큰만 -- 화면 AC
- [ ] `app/views/dashboard/_period_tabs.html.erb`·`_filter_bar.html.erb` -- `base_path` local(기본 root_path) 추가해 popular 재사용 -- 필터 재사용
- [ ] `test/controllers/popular_controller_test.rb`·`test/views/popular_view_test.rb`·`test/views/shared_components_test.rb` -- 200·읽기 전용·배수 desc 정렬·밴드 그룹핑/평면·필터(기간·카테고리·유형·evergreen)·스파크라인 콜드/렌더·자사 유사 뱃지 3종·youtube 링크·"구독자 대비 조회수" 부재·원시 색 부재·N+1 프리로드 -- 검증

**Acceptance Criteria:**
- Given 물질화된 배수·유사영상 값, when 인기 콘텐츠 화면을 열면, then 테이블 컬럼이 순번/영상/채널/업로드일/조회수/성과 배수/트렌드(스파크라인)/자사 유사영상이다.
- Given 행, when 렌더하면, then 배수가 §1.5 색 밴드로 강조되고 raw 조회수는 뮤트이며 유형 배지·구독자 밴드·주제 힌트가 표시된다.
- Given 영상 행, when 클릭하면, then 유튜브 URL로 이동한다.
- Given 스파크라인, when 시계열 스냅샷이 부족하면, then "데이터 수집 중" 플레이스홀더로 자리를 유지한다(위젯별, 전역 배너 없음).
- Given 좁은 화면, when 보면, then 테이블이 가로 스크롤되고 본문은 가로로 깨지지 않으며 다국어 제목이 말줄임된다.
- Given 필터, when 기간·카테고리·유형을 바꾸면, then Video 스코프에 적용되고(6.2 defer 실현) empty/loading/error 상태가 각각 표시된다.

## Review Triage Log

이중 적대 리뷰(Blind Hunter + Edge Case Hunter). 두 리뷰어 모두 test DB에 실제 쿼리를 돌려 헤드라인 우려를 실증했다.

**실증으로 기각(오탐)**
- **`video.video_score` N+1 없음.** 컨트롤러 `includes(video: [:channel, :daily_stats])`에 `:video_score`가 없지만, `Video has_one :video_score` / `VideoScore belongs_to :video`에 스코프·옵션이 없어 Rails 8이 `inverse_of`를 자동 해소한다. 행 반복 중 `s.video.video_score` 접근이 **0 쿼리**로 측정됨. (단, 향후 두 연관 중 하나에 스코프가 붙으면 자동 inverse_of가 깨져 N+1이 부활 — `_video_row` 헤더 계약 주석 유지.)
- **`joins + includes + hash-where` 충돌 없음.** 해시 조건은 `references`를 자동 트리거하지 않아 `includes`가 `eager_load`로 승격되지 않음. channels는 필터용 INNER JOIN + 별도 preload(경미한 중복, 오류·행 중복 없음). 테이블 별칭 `videos.`/`channels:`/`videos:` 모두 정확.
- **읽기 전용(AD-3)·XSS·후방호환·band nil 정렬·콜드스타트** 모두 정상.

**패치(적용)**
1. **[Moderate] 밴드 모드 순번이 밴드 경계를 넘어 누적** — 전역 카운터라 밴드 B의 `#7`이 성과 7위처럼 오독됨. → 밴드별로 순번 1부터 리셋(각 밴드=자기 리더보드). 평면 모드는 전역 순위 유지. 목업은 평면(토글 기본)만 규정하고 밴드 토글 상태는 미규정 → 정직한 해석으로 리셋 채택.
2. **[Minor·정직성] 스파크라인 결측 view_count → 0 강압** — nil을 0으로 눌러 가짜 바닥선. → 창 안에 nil이 하나라도 있으면 `nil` 반환해 §4.7 "데이터 수집 중" 자리 유지(AD-9).
3. **[Minor] youtube_video_id 미인코딩** — 비정규 스텁 id의 `&`·공백이 쿼리 오염. → `CGI.escape`.
4. **[Minor·a11y] 트렌드 셀 대체 텍스트 없음** — `aria-hidden` → `role="img" aria-label="최근 7일 조회수 추이"`.
5. **[Minor] 죽은 분기 `n == 1`** — 가드로 n은 항상 7 → 제거(불가능 상태 방어 코드 제거).
6. **[Very Low·방어] nil 밴드 정렬 센티넬 `4` 하드코딩** — 밴드 티어가 AD-4 튜닝으로 4개 되면 충돌. → `Float::INFINITY`.

**Defer(의도된 동작·문서화)**
- **`published_at IS NULL`이 기간 필터(1w/1m/3m)에서 조용히 제외** — 업로드일 미상 영상은 "이번 주/달" 기간 창에 분류 불가하므로 날짜 필터에서 빠지는 게 맞다(에버그린 탭은 날짜 아닌 `evergreen_candidate` 사용). 저심각·의도된 해석으로 유지.
- **`(scores.first && …)` 중복 가드** — `group_by`는 빈 그룹을 내지 않아 무해. 정보성 방어로 유지.

**추가 테스트(회귀 방지)** — `test/helpers/scoring_display_helper_test.rb`에 5건: own_match_badge 3종·youtube_watch_url 인코딩·스파크라인 콜드스타트/정상 렌더/결측 가드.

## Design Notes

**공유 행을 §4.3 정본으로.** 6.1 `_video_row`는 일반형이었고 §4.3이 급상승 테이블을 정확히 정의한다 — 순번(#)·유형/밴드/주제 인라인 칩(별 컬럼 아님)·자사 유사영상 §1.4 뱃지(없음 neutral/1개 caution/2개+ danger)·트렌드 스파크라인 셀. `_video_row`를 이 정본으로 정렬하고 `rank`·`sparkline`을 옵션 local로 둔다(현재 소비처는 6.1 테스트뿐이라 정렬 안전). 6.1 테스트를 정본에 맞춘다.

**스파크라인은 읽기만(AD-3).** `VideoDailyStat`(preload) 최근 7 view_count를 정규화해 인라인 SVG polyline(primary 계열 토큰). 스냅샷 수 < `cold_start_snapshots.sparkline`이면 렌더하지 않고 §4.7 "데이터 수집 중" 자리(위젯별, AD-7 — 1일차엔 대부분 콜드). 저장 값 읽기이지 성과·유사도 재계산이 아니다.

**필터 실현(6.2 defer).** 기간·카테고리·유형·에버그린을 `VideoScore.ranked`에 joins/where로 적용(DashboardHelper 화이트리스트 재사용). period 1w/1m/3m는 업로드 경과, evergreen은 `evergreen_candidate`. 밴드 그룹핑은 로드 후 `subscriber_band`로 Ruby group(밴드는 순수 함수 3.3, 요청 경로 허용). 정렬은 밴드 내에서도 성과 배수 desc.

**필터 바 재사용.** `_period_tabs`/`_filter_bar`에 `base_path` local을 더해 대시보드(root)·인기(popular)가 같은 컨트롤을 공유한다 — 쿼리 파라미터 병합은 6.2에서 string 키로 수정 완료.

## Verification

**Commands:**
- `bin/rails test test/controllers/popular_controller_test.rb test/views/popular_view_test.rb test/views/shared_components_test.rb` -- expected: 전부 통과
- `bin/rails test test/design_tokens_test.rb` -- expected: 토큰 회귀 없음
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/popular app/views/shared` -- expected: 결과 없음
- `grep -rniE "text-(blue|green|red|amber)-[0-9]|bg-(blue|green|red|amber)-[0-9]" app/views/popular app/views/shared` -- expected: 원시 색 없음

## Auto Run Result

Status: done

- **구현**: 인기 콘텐츠 화면(PopularController#index, 얇은 읽기 전용). VideoScore.ranked(성과 배수 desc) + 기간/카테고리/유형/에버그린 필터 + 밴드 그룹핑/평면 토글. §4.3 정본 `_video_row` 재사용(순번·썸네일+제목 유튜브 링크·인라인 칩·성과 배수 히어로·트렌드 스파크라인·자사 유사영상 §1.4 뱃지). 스파크라인은 VideoDailyStat 최근 7일 정규화 인라인 SVG, 콜드스타트 시 §4.7 자리 유지. 필터 바/기간 탭은 `base_path`로 대시보드와 공유.
- **리뷰**: 이중 적대 리뷰 → 6건 패치, 2건 defer(위 Review Triage Log). N+1·joins/includes·읽기전용·XSS는 실증으로 기각.
- **테스트**: `bin/rails test` — **391 runs, 1359 assertions, 0 failures, 0 errors, 0 skips**(6.3 헬퍼 회귀 테스트 +5). grep — 금지 라벨·원시 팔레트 색 부재.
