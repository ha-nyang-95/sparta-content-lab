---
title: 'Story 6.5: 콘텐츠 갭 화면 — 도넛 + 4구간 버킷'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-1-shared-display-components.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-3-popular-videos-table.md'
  - '{project-root}/DESIGN.md'
warnings: []
baseline_revision: 'e486735dd3d841674d0eb47743244cddba702946'
final_revision: ''
---

<intent-contract>

## Intent

**Problem:** 콘텐츠 갭 화면이 placeholder다. 운영자가 "경쟁은 만들었는데 우리는 안 만든" 주제(콘텐츠 기회)를 한눈에 볼 도넛·분포·구간별 영상이 없다.

**Approach:** `ContentGapController`가 **읽기 전용 index**(AD-3)로 물질화된 `VideoScore.content_gap_bucket`(4.3, 경쟁 is_own:false 영상만)을 집계해 §4.6 도넛(4구간 분포 + 중앙 "콘텐츠 기회" 퍼센트) + 범례 + 선택 구간의 영상 리스트(6.1 `_video_row` 재사용)를 렌더한다. 도넛 중앙 % = **버킷 기회 가중 평균**(운영자 결정, content_gap_values 재사용). 재계산 없이 물질화 버킷 집계·표시 변환만.

## Boundaries & Constraints

**Always:**
- **읽기 전용**(AD-3) — `VideoScore` 의 물질화된 `content_gap_bucket`·`own_match_count`·`performance_multiple` 만 조회·집계. 임베딩·유사도·분류 **재계산 금지**(배치 ClassifyContentGap 이 이미 물질화). 도넛 각도·가중 평균은 물질화 버킷 집계 위 **순수 표시 변환**(밴드 그룹핑과 동급 — 허용).
- **분류 대상 = 경쟁 영상만** — `channels.is_own = false AND excluded = false AND content_gap_bucket IS NOT NULL`(ClassifyContentGap 정합 — 자사·미분류 nil 제외).
- **도넛(§4.6)** — 인라인 SVG. 4구간 진→연 primary 램프 + neutral 1개: `not_made`→`primary-600`, `one`→`primary-500`, `few`→`primary-100`, `saturated`→`border`(#E5E7EB neutral). 세그먼트 각도 = 버킷 건수 비율. 중앙 `text-score text-primary-600` = 콘텐츠 기회 %. 색 매핑은 dataviz 스킬 아니라 DESIGN 따름.
- **중앙 "콘텐츠 기회" %** = `Σ(bucket_count × content_gap_value) / total_classified × 100`(반올림). `content_gap_value` = `Scoring::Config.fetch(:opportunity_score, :normalization)[:content_gap_values]`(not_made 1.0/one 0.66/few 0.33/saturated 0.0). total 0 이면 nil(콜드).
- **범례(§4.6)** — 4구간 각각: 색 dot(rounded-full) + 라벨(미제작/유사 1개/유사 2개+/포화, `text-body`) + 값(건수, `text-ink-muted tabular`). 라벨 문구는 Glossary 정합.
- **구간 필터** — 범례/세그먼트를 `?bucket=<key>` 링크로(6.3 기간 탭 방식, string 키 병합). 화이트리스트(`VideoScore::CONTENT_GAP_BUCKETS`), 기본 `not_made`(최대 기회). 선택 구간 영상 리스트는 6.1 `_video_row`(rank 없음·sparkline 없음) 재사용, `includes(video: [:channel, :daily_stats])` 프리로드(N+1 계약, video_score auto-inverse).
- **콜드스타트/정직성**(§4.7) — 분류된 경쟁 스코어 0(임베딩/classify 미완)이면 도넛 자리에 "데이터 수집 중"(dashed) 유지·**위젯 숨김 금지**. 선택 구간 건수 0이면 그 구간 리스트만 빈 상태(도넛은 계속 렌더).
- 색·간격 **DESIGN §10 토큰만**(원시 색 금지, AD-15). 라벨 "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**. 반응형(§5): 도넛+범례 모바일 스택, 리스트 테이블 `overflow-x-auto`, **본문 가로 스크롤 금지**. 다국어(§7). nil 방어(AD-9).

**Block If:**
- (없음 — §4.6·운영자 결정[중앙%=기회 가중 평균]·4.3 버킷으로 확정. 신규 디자인이면 운영자 문의.)

**Never:**
- 웹 요청 경로에서 임베딩·유사도·버킷 재분류(물질화 버킷 읽기만). 자사(is_own:true)·미분류(nil) 영상을 도넛/분포에 포함. 원시 Tailwind 색. "구독자 대비 조회수". 성과 배수에 amber/red. 도넛 색을 §4.6 밖 팔레트로. 콜드 시 도넛 위젯 숨김.
- 컨트롤러에 계산 로직(집계 쿼리·표시 변환만). 저장 영상·에버그린·설정(6.6~6.7) 기능.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 분포 집계 | 분류된 경쟁 스코어 | group(:content_gap_bucket).count | — |
| 중앙 % | 분포 | 기회 가중 평균 ×100 반올림 | total 0→nil |
| 도넛 색 | 4구간 | primary-600/500/100 + border | — |
| 범례 | 4구간 | dot+라벨+건수 | 0 건수 구간도 표기 |
| 구간 필터 | ?bucket=one | 그 버킷 영상만 | 잘못된 값→not_made |
| 구간 리스트 | 선택 버킷 | _video_row(배수 desc) | 0건→빈 구간 안내 |
| 콜드 | 분류 0 | 도넛 "데이터 수집 중" 자리 | AD-7 |
| 경쟁만 | is_own filter | 자사·nil 제외 | — |
| 읽기 전용 | GET | VideoScore 쓰기 없음 | — |
| 검증 요망 | needs_verification | ⚠ 플래그(_video_row) | — |
| 모바일 | 좁은 뷰포트 | 도넛/범례 스택, 리스트 가로 스크롤 | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |
| 다국어 | 한·일 제목 | truncate·break-keep·title | §7 |

</intent-contract>

## Code Map

- `app/controllers/content_gap_controller.rb` -- `#index` 얇게 — 경쟁 분류 스코어 집계(`@distribution`)·선택 버킷 영상 프리로드(`@scores`)·화이트리스트(`@bucket`). 계산 없음.
- `app/helpers/content_gap_helper.rb` -- (신규) `content_gap_opportunity_pct(distribution)`(기회 가중 평균)·`content_gap_segments(distribution)`(SVG 세그먼트 dash/offset·색·라벨·건수)·`content_gap_bucket_label(key)`·`permitted_content_gap_bucket(params)`. 전부 읽기·표시 변환.
- `app/views/content_gap/index.html.erb` -- placeholder 교체: 도넛+범례 카드 → 구간 탭(?bucket) → §4.3 영상 테이블(_video_row) → empty/loading/error
- `app/views/content_gap/_donut.html.erb` -- §4.6 인라인 SVG 도넛(세그먼트 + 중앙 %) 또는 콜드 자리
- `app/views/content_gap/_legend.html.erb` -- 4구간 범례(dot+라벨+건수, 선택 강조 링크)
- `config/scoring.yml` -- `opportunity_score.normalization.content_gap_values`(기존)·`content_gap.saturation_min`(기존)
- `test/controllers/content_gap_controller_test.rb`·`test/helpers/content_gap_helper_test.rb` -- 200·읽기 전용·경쟁만·분포·가중 평균·세그먼트·구간 필터·콜드·라벨/색 금지·N+1

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/content_gap_helper.rb` -- `BUCKET_ORDER = %w[not_made one few saturated]`; `BUCKET_LABELS`(미제작/유사 1개/유사 2개+/포화); `BUCKET_STROKE`(primary-600/500/100·border). `content_gap_opportunity_pct(distribution)`: values=`Scoring::Config.fetch(:opportunity_score, :normalization)[:content_gap_values]`; total=distribution.values.sum; total.zero?→nil; else `(Σ count×values[bucket.to_sym]/total*100).round`. `content_gap_segments(distribution, circumference:)`: BUCKET_ORDER 순 각 버킷 {key,label,count,fraction,stroke_class,dash,offset}(누적 offset). `content_gap_bucket_label(key)`; `permitted_content_gap_bucket(params)`(CONTENT_GAP_BUCKETS 화이트, 기본 "not_made") -- 헬퍼 AC
- [ ] `app/controllers/content_gap_controller.rb` -- `#index`: `base = VideoScore.joins(video: :channel).where(channels: {is_own: false, excluded: false}).where.not(content_gap_bucket: nil)`; `@distribution = base.group(:content_gap_bucket).count`; `@bucket = helpers.permitted_content_gap_bucket(params)`; `@scores = base.where(content_gap_bucket: @bucket).includes(video: [:channel, :daily_stats]).order(Arel.sql("performance_multiple DESC NULLS LAST")).order(video_id: :asc)`. **계산 없음** -- 컨트롤러 AC
- [ ] `app/views/content_gap/_donut.html.erb` -- `@distribution` 총합>0 이면 §4.6 SVG 도넛(`content_gap_segments` 로 `<circle>` per 세그먼트 stroke-dasharray·dashoffset, viewBox 정사각, -90° 회전) + 중앙 `text-score text-primary-600` `content_gap_opportunity_pct` + "콘텐츠 기회"; 아니면 `shared/honesty_status` status: :collecting("데이터 수집 중") 자리 유지 -- 도넛 AC
- [ ] `app/views/content_gap/_legend.html.erb` -- BUCKET_ORDER 순 dot(stroke_class 대응 bg)+라벨+건수, `?bucket=` 링크(선택 `@bucket` 강조, string 키 병합) -- 범례 AC
- [ ] `app/views/content_gap/index.html.erb` -- placeholder 교체: 도넛+범례 반응형 카드(모바일 스택) → §4.3 테이블(`overflow-x-auto min-w`, thead 영상/채널/업로드일/조회수/성과 배수/자사 유사영상, `_video_row` rank 없음·sparkline 없음) → 선택 구간 0건 빈 안내 → 콜드/loading/error. DESIGN §10 토큰만·§7·§5 -- 화면 AC
- [ ] `test/controllers/content_gap_controller_test.rb`·`test/helpers/content_gap_helper_test.rb` -- 200·GET 읽기 전용(VideoScore.count 불변)·경쟁만(자사·nil 제외)·분포 집계·가중 평균(전부 미제작 100·전부 포화 0·혼합)·세그먼트 합=원둘레·구간 필터(기본 not_made·잘못된 값 폴백)·콜드(분류 0→placeholder)·"구독자 대비 조회수" 부재·원시 색 부재·N+1 프리로드 -- 검증

**Acceptance Criteria:**
- Given 물질화된 경쟁 영상 content_gap_bucket, when 콘텐츠 갭 화면을 열면, then §4.6 도넛(4구간 분포)·중앙 콘텐츠 기회 %·범례(건수)가 렌더된다.
- Given 도넛 중앙 %, when 계산하면, then 버킷 기회 가중 평균(content_gap_values)×100 이고 전부 미제작=100%·전부 포화=0% 이다.
- Given 범례/세그먼트, when 한 구간을 선택하면, then 그 버킷 경쟁 영상이 6.1 `_video_row`로 성과 배수 desc 나열되고 각 행 자사 유사영상 수가 도넛 분류와 일치한다.
- Given 분류된 경쟁 스코어가 없음(임베딩/분류 미완), when 화면을 열면, then 도넛 자리에 "데이터 수집 중"이 유지되고 위젯이 숨겨지지 않는다.
- Given GET /content-gap, when 요청하면, then VideoScore 를 쓰지 않는다(읽기 전용, AD-3).
- Given 좁은 화면, when 보면, then 도넛·범례가 스택되고 리스트는 가로 스크롤되며 본문은 가로로 깨지지 않는다.

## Design Notes

**도넛·가중 평균은 물질화 위 표시 변환(AD-3 허용).** group-count·SVG 각도·가중 평균은 저장된 `content_gap_bucket` 을 요약할 뿐 임베딩/유사도/분류를 재계산하지 않는다(6.3 밴드 그룹핑·스파크라인 정규화와 동급). 중앙 % 의미는 운영자 결정 = 버킷 기회 가중 평균([[content-gap-donut-center]]).

**4구간 색은 §4.6 진→연 램프.** §10 primary 톤이 50/100/500/600/700 뿐이라 3-스텝 램프는 primary-600(미제작=최대 기회)→primary-500(유사1)→primary-100(유사2+), saturated 는 neutral `border`(#E5E7EB). 신규 색 발명 없음.

**분류 대상은 경쟁만.** ClassifyContentGap 이 is_own:false·not excluded 스코어에만 버킷을 물질화하고 자사·미분류는 nil — 도넛/분포/리스트 모두 `where.not(content_gap_bucket: nil)` + is_own:false 로 정합. FR-18: 행의 자사 유사영상 수와 도넛 분류가 같은 own_match_count 소재지에서 파생.

**구간 리스트는 6.1 재사용.** `_video_row`(rank 없음·sparkline 없음) — 6.3에서 옵션 local 로 정본화. 성과 배수 desc·video_id 타이브레이크(nulls last). 기본 구간 not_made(최대 기회); 해당 구간 0건이면 도넛은 유지하고 리스트만 빈 안내(운영자가 다른 세그먼트 선택).

## Review Triage Log

이중 적대 리뷰(Blind Hunter + Edge Case Hunter). 두 리뷰어가 SVG 기하·N+1·가중 평균을 실증하고 헤드라인 우려 전부를 정상으로 확인 — 이례적으로 깨끗한 구현.

**실증으로 기각(오탐/정상)**
- **읽기 전용(AD-3)** — 컨트롤러는 joins/where/group/count/includes/order/to_a, 헬퍼는 @distribution 해시 위 순수 산술, 뷰는 렌더만. save/update/Similarity/Embedding/classify grep 0건. 재계산 유입 없음.
- **SVG 도넛 기하** — `offset=-누적길이` + dasharray `[dash, C-dash]` + `rotate(-90 60 60)` → 세그먼트가 12시부터 간극·겹침 없이 연속 타일링, Σdash=C(total>0). 부호·회전·butt 캡 모두 정확(추론 아닌 검증).
- **가중 평균** — content_gap_values 심볼 키 ↔ DB 문자열 키를 `bucket.to_sym` 로 브리지. Float#round half-away → 66.5→67 등 정상. 전부 미제작 100·전부 포화 0 확인.
- **N+1** — `includes(video: [:channel, :daily_stats])` + auto-inverse(`score.video.video_score` identity)로 행 루프 **0 쿼리**(6.3과 동일 기전).
- **경쟁 필터·정렬·XSS·쿼리 병합(string 키)·잘못된/배열 ?bucket→not_made·콜드 vs 빈 구간 게이트·원시 색/금지 라벨** — 전부 정상 실증.

**패치(적용)**
1. **[Low·드리프트] 버킷 키 3중 소재지 미정렬 시 500 위험** — `values[bucket.to_sym]` 무가드 → 모델 CONTENT_GAP_BUCKETS·헬퍼 BUCKET_ORDER·scoring.yml content_gap_values 가 어긋나면(운영자 튜닝 시) nil 곱셈 500·도넛 빈 링. 오늘은 3곳 동일이라 불가하나 방어. → **락스텝 테스트** 추가(5개 소재지 키 정렬 강제) — 런타임 코드 팽창 없이 드리프트를 테스트 시점에 포착.
2. **[Nit·a11y] 도넛 수치 대체 텍스트 없음** — 제네릭 aria-label. → `aria-label="콘텐츠 기회 N%"` 로 퍼센트 포함(범례가 구간 건수는 텍스트로 이미 노출).

**Defer(문서화)**
- **F2 기본 구간 not_made 가 비었는데 타 구간에 데이터** — 스펙 의도(not_made=이 화면의 핵심 "기회" 구간, 비어있음 자체가 정보). 빈 구간 안내 문구 유지, 운영자가 세그먼트 선택. 저심각 UX.
- **saturated arc == 트랙 색(둘 다 stroke-border)** — §4.6 "neutral 1개" 규정대로(포화=중립·비강조). 버그 아님.
- **index/donut total 중복 계산** — 둘 다 @distribution 파생이라 발산 불가. 무해.

**추가 테스트(회귀 방지)** — 헬퍼 락스텝 1건. 전 스위트 429 runs 0 failures.

## Verification

**Commands:**
- `bin/rails test test/controllers/content_gap_controller_test.rb test/helpers/content_gap_helper_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/content_gap app/helpers/content_gap_helper.rb` -- expected: 결과 없음
- `grep -rniE "(text|bg|border|stroke|fill)-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-[0-9]" app/views/content_gap app/helpers/content_gap_helper.rb` -- expected: 원시 색 없음

## Auto Run Result

Status: done

- **운영자 결정**: 도넛 중앙 "콘텐츠 기회" % = 버킷 기회 가중 평균(content_gap_values 재사용). AskUserQuestion 확정, 메모리 기록([[content-gap-donut-center]]).
- **구현**: 읽기 전용 ContentGapController#index(경쟁 is_own:false 분류 스코어 집계, AD-3) + §4.6 인라인 SVG 도넛(4구간 진→연 primary 램프 + neutral) + 범례(?bucket 필터) + 선택 구간 §4.3 영상 리스트(6.1 _video_row 재사용). 콜드스타트 시 도넛 자리 유지.
- **리뷰**: 이중 적대 리뷰 — 헤드라인 전부 실증 정상(SVG 기하·N+1·읽기전용·가중 평균·XSS). 2건 패치(버킷 키 락스텝 테스트·도넛 a11y %), 3건 defer.
- **테스트**: `bin/rails test` — **429 runs, 1469 assertions, 0 failures, 0 errors, 0 skips**(회귀 +1). grep — 금지 라벨·원시 팔레트 색 부재. tailwindcss:build 로 stroke-*/bg-border 생성 확인.
