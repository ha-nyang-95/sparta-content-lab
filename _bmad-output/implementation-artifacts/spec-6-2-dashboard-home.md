---
title: 'Story 6.2: 대시보드 홈 — 추천 3개 + 기간 탭 + 필터 바'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-1-shared-display-components.md'
  - '{project-root}/DESIGN.md'
warnings: []
baseline_revision: '9fa12ae6f6263b08d1713259357a94fb8281e642'
final_revision: 'a0088563a9cf1a58b9e248cf38d835e8ab05457a'
---

<intent-contract>

## Intent

**Problem:** 운영자가 한 화면에서 이번 주를 훑어야 한다. 대시보드 홈에 추천 3개·기간 탭·필터가 없고 placeholder만 있다.

**Approach:** `DashboardController#index`(얇게, 물질화 값 읽기만)가 `Recommendation`·참고 영상을 로드하고, 대시보드 홈 뷰가 "이번 주 추천 콘텐츠 3개" 카드(§4.2)·기간 탭(§4.8)·카테고리/유형 드롭다운·밴드 그룹핑 평면 토글·시계열 위젯 콜드스타트 자리(AD-7)를 목업대로 렌더한다. 색은 DESIGN.md §10 토큰만, 재계산 없음(AD-3), 6.1 공유 컴포넌트 재사용.

## Boundaries & Constraints

**Always:**
- 컨트롤러는 **얇게** — 물질화 값(`Recommendation`·`Video.video_score`·`Channel`)을 **읽기만**, 스코프·쿼리만. **유사도·중앙값·임베딩 재계산 금지**(AD-3). 참고 영상은 `Video.where(id: reference_video_ids).includes(:video_score, :channel)`로 프리로드(6.1 N+1 계약).
- 색·간격·radius·폰트는 **DESIGN.md §10 토큰만**(원시 Tailwind 색 금지, AD-15). 추천 카드 §4.2, 기간 탭·드롭다운 §4.8, 스켈레톤 pulse §6, 정직성 §4.7.
- "이번 주 추천 콘텐츠 3개" 카드 — 번호 뱃지(`bg-primary-600` 흰 숫자)·제목(`text-h3 line-clamp-2`)·태그 칩(`bg-primary-50 text-primary-600`)·스탯 라인(경쟁 영상 N개·**성과 배수 N배**·자사 유사 영상 유무)·기회 점수(`text-score text-primary-600` +`/100`)·근거 보기 outline 버튼(펼침). 값은 물질화에서 파생 — 경쟁 영상 수=`reference_video_ids.size`, 성과 배수=참고 영상 `video_score.performance_multiple` 최대, 자사 유사=참고 영상 `own_match_count>0` 유무.
- **정직성(AD-16)**: 추천 자격<3이면 억지로 채우지 않고 있는 개수만 + "이번 주 N개 확보" 문구(5.2 데이터 반영). 추천 0개는 empty 상태. 시계열 위젯(급상승 VPD·스파크라인·검증 에버그린·구독자 증감)은 **위젯별 준비도**(AD-7, `cold_start_snapshots` 임계 vs 스냅샷 수)로 "D+n 데이터 수집 중"을 **개별** 표시(전역 배너 금지) — 값 없어도 자리 유지(§4.7 collecting, `shared/_honesty_status`).
- 기간 탭(§4.8 세그먼트, 최근 1주/1개월/3개월/에버그린) — 업로드 기간 필터로 동작(쿼리 파라미터, 콜드스타트에서도). 카테고리·유형 드롭다운(한국어 교육/영어 교육/일반+Shorts) — 필터 파라미터. 밴드 그룹핑↔평면 토글(파라미터). Turbo·쿼리 파라미터, 서버 렌더(SPA 전환 금지 §6).
- 라벨 정합 — "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**(목업 텍스트가 구식이나 DESIGN §9가 정정 지시 — 정정 라벨 사용). 편향 2기전은 6.1 `performance_bias_note`.
- 반응형(§5): 좌측 내비 모바일 축소(기존 레이아웃), 그리드 스택, **본문 가로 스크롤 금지**, 테이블 영역만 가로 스크롤 허용.
- nil/empty 방어(AD-9): 값 없는 위젯은 상태로 표시(숨김 없이).

**Block If:**
- (없음 — 목업·DESIGN.md·6.1 컴포넌트가 정의. 목업/DESIGN에 없는 신규 디자인이면 운영자 문의.)

**Never:**
- 웹 요청 경로 재계산(물질화 읽기만). 원시 Tailwind 색. "구독자 대비 조회수". 전역 콜드스타트 배너(위젯별). 자격 미달 추천 억지 채움. 위젯 숨김.
- 급상승 테이블 실 렌더·경쟁 채널 리스트·도넛·에버그린 카드 실 콘텐츠(6.3~6.6 — 여기선 자리·콜드스타트만). 컨트롤러에 계산 로직.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 추천 3개 | Recommendation 3행 | 카드 3개(번호·기회 점수·근거 보기) | — |
| 추천 <3 | Recommendation 2행 | 2개 + "이번 주 2개 확보" | — |
| 추천 0 | 0행 | empty 상태(N개 확보/수집 중) | — |
| 근거 보기 | 카드 버튼 클릭 | 참고 경쟁 영상 펼침(Stimulus) | — |
| 기간 탭 | ?period=1m | 활성 탭·업로드 기간 필터 | — |
| 에버그린 탭 | ?period=evergreen | 에버그린 탭 활성 | — |
| 카테고리 필터 | ?category=한국어교육일반 | 드롭다운 반영 | — |
| 평면 토글 | ?layout=flat | 밴드 그룹핑↔평면 | — |
| 위젯 콜드스타트 | 스냅샷<임계 | 위젯별 "D+n 데이터 수집 중"(개별) | AD-7 |
| 카드 성과 배수 | 참고 영상 배수 | 성과 배수 N배(물질화 읽기) | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |
| 모바일 | 좁은 뷰포트 | 스택·본문 가로 스크롤 없음 | — |

</intent-contract>

## Code Map

- `app/controllers/dashboard_controller.rb` -- `#index` 얇게 — `@recommendations`·참고 영상 프리로드·필터 파라미터·위젯 준비도(읽기만)
- `app/views/dashboard/index.html.erb` -- 홈 레이아웃(placeholder 교체) — 탭·필터·추천·위젯 자리
- `app/views/dashboard/_recommendation_card.html.erb` -- §4.2 추천 카드
- `app/views/dashboard/_period_tabs.html.erb`·`_filter_bar.html.erb` -- §4.8 탭·드롭다운
- `app/helpers/dashboard_helper.rb` -- 필터 파라미터 화이트리스트·위젯 준비도(cold_start_snapshots)·"N개 확보"
- `app/javascript/controllers/*_controller.js` -- 근거 보기 펼침·탭/필터 내비(Stimulus)
- `app/views/shared/_performance_cell`·`_video_row`·`_honesty_status`·`ScoringDisplayHelper` -- 6.1 재사용
- `config/scoring.yml` -- `cold_start_snapshots`(기존)
- `test/controllers/dashboard_controller_test.rb`·`test/views/dashboard_*` -- 200·읽기만·추천·정직성·탭·필터·콜드스타트·라벨 금지

## Tasks & Acceptance

**Execution:**
- [x] `app/controllers/dashboard_controller.rb` -- `#index`: `@recommendations = Recommendation.order(:rank)`; `@videos_by_rec = Video.where(id: @recommendations.flat_map(&:reference_video_ids).uniq).includes(:video_score, :channel).index_by(&:id)`; `@period/@category/@type/@layout`을 params에서 화이트리스트로; `@widget_readiness` = 위젯별 준비도(helper). **계산 없음** -- 얇은 컨트롤러 AC
- [x] `app/helpers/dashboard_helper.rb` -- `period_options`·`category_options`·`type_options`(화이트리스트), `widget_collecting?(widget)`(`ChannelDailyStat`/`VideoDailyStat` 스냅샷 수 vs `Scoring::Config.fetch(:cold_start_snapshots, widget)`), `recommendation_shortfall_note(count, target)`("이번 주 N개 확보") -- 헬퍼 AC
- [x] `app/views/dashboard/index.html.erb` -- placeholder 교체: 기간 탭 + 필터 바 → "이번 주 추천 콘텐츠 3개" 헤더 + 카드 그리드(3열, 반응형 스택) → 시계열 위젯 자리(급상승·경쟁 채널·콘텐츠 기회·에버그린 — 콜드스타트/자리). empty/loading/error 상태. DESIGN §10 토큰만 -- 홈 레이아웃 AC
- [x] `app/views/dashboard/_recommendation_card.html.erb` -- §4.2: 번호 뱃지·제목·태그 칩·스탯 라인(경쟁 영상 수·성과 배수·자사 유사)·기회 점수·근거 보기(펼침 대상 참고 영상). 로컬 `recommendation`·`rank`·`videos_by_rec` -- 카드 AC
- [x] `app/views/dashboard/_period_tabs.html.erb`·`_filter_bar.html.erb` -- §4.8 세그먼트 탭(활성 primary-600)·드롭다운(surface·border·chevron). 쿼리 파라미터 링크 -- 탭·필터 AC
- [x] `app/javascript/controllers/disclosure_controller.js`(또는 재사용) -- 근거 보기 펼침 토글(Stimulus). 탭/필터는 링크(쿼리 파라미터)라 JS 최소 -- 인터랙션
- [x] `test/controllers/dashboard_controller_test.rb`·`test/views/dashboard_view_test.rb` -- 200·읽기 전용(쿼리 수 상한·계산 없음)·추천 3개/N개 정직성/0개 empty·기간 탭·필터·위젯 콜드스타트 개별·"구독자 대비 조회수" 부재·원시 색 부재·모바일 클래스 -- 검증

**Acceptance Criteria:**
- Given 물질화된 추천·배수, when 대시보드 홈을 열면, then 상단에 "이번 주 추천 콘텐츠 3개" 카드(번호 뱃지·기회 점수·근거 보기 펼침)가 표시된다.
- Given 기간 탭, when 클릭하면, then 최근 1주/1개월/3개월 업로드 기간 필터로 동작하고(콜드스타트에서도) 에버그린 탭이 있다.
- Given 필터, when 열면, then 카테고리·유형 드롭다운이 있고 밴드 그룹핑↔평면 토글이 가능하다.
- Given 상태, when 데이터가 없으면, then empty("N개 확보")·loading(스켈레톤)·error가 각각 표시되고 시계열 위젯은 위젯별 "D+n 데이터 수집 중"으로 개별 표시된다(전역 배너 금지, 자리 유지).
- Given 라벨, when 렌더하면, then "구독자 대비 조회수"가 없고 "성과 배수(채널 평소 대비)"로 통일된다.
- Given 모바일, when 좁은 뷰포트로 보면, then 레이아웃이 깨지지 않고 본문 가로 스크롤이 없다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6: (high 1, medium 0, low 5)
- defer: 2: (medium 1, low 1)
- reject: 2: (low 2)
- addressed_findings:
  - `[high]` `[patch]` `_period_tabs`·`_filter_bar` `request.query_parameters.merge(period: key)` — query_parameters 는 string 키인데 symbol 키 merge → `period=old&period=new` 공존, 재클릭 시 옛 값이 이겨 필터가 실제로 안 바뀜. string 키(`"period" => key`, `param.to_s`, `"layout"`)로 수정.
  - `[low]` `[patch]` `index.html.erb` 추천 0개 시 헤더 "0개 확보" 칩 + empty 카드 "0개 확보" 중복 — 헤더 칩을 `@recommendations.any?`일 때만.
  - `[low]` `[patch]` `dashboard_helper.rb` `widget_snapshot_count` 미memoize로 COUNT 6회 — 요청당 소스별(video/channel) memoize.
  - `[low]` `[patch]` `_recommendation_card` 배수 표기 "%.1f배" vs 공유 `_performance_cell` "×" 불일치 — 공유 컴포넌트(canonical) "×"로 통일.
  - `[low]` `[patch]` `_recommendation_card` "경쟁 영상 N개"가 전 reference_ids 계수하나 배수·펼침은 존재분만 — 존재 영상만 계수(`present_video_ids`).
  - `[low]` `[patch]` `_recommendation_card` 펼침 루프가 댕글링(삭제) reference id 로 phantom "영상 {id}" 행 — `present_video_ids`로 nil 영상 스킵(AD-10 방어).
- deferred: (1) 기간·카테고리·유형 필터의 **급상승 비디오 테이블 적용**과 밴드 그룹핑↔평면 **렌더링** — 대상 테이블이 6.2에 없다(6.3 소관). 6.2는 컨트롤·URL 상태를 제공하고 6.3이 파라미터를 테이블 쿼리·그룹핑에 적용한다. (2) 추천 카드 태그 칩(§4.2 문법/초급~중급) — Recommendation/TopicCluster에 장르·레벨 데이터 소스가 없어 날조하지 않고 생략. 소스 추가 시 칩 슬롯.
- rejected(noise): unknown widget symbol 시 Config.fetch KeyError(유효 호출자만·fail-fast 확립 패턴), category 키↔라벨 매핑(언어교육참고→"영어 교육" 등은 목업 드롭다운 라벨 정합·의도된 4분류 UX 단순화).

## Design Notes

**얇은 컨트롤러·읽기 전용(AD-3).** 컨트롤러는 `Recommendation.order(:rank)`와 참고 영상 프리로드, 필터 파라미터 화이트리스트, 위젯 준비도만. 성과 배수·유사도·중앙값은 이미 물질화된 컬럼을 읽는다(재계산 금지). 카드 스탯(경쟁 영상 수·성과 배수·자사 유사)은 참고 영상의 `reference_video_ids.size`·`video_score.performance_multiple`·`own_match_count`에서 파생.

**콜드스타트는 위젯별(AD-7).** 시계열 위젯(급상승 VPD·스파크라인·검증 에버그린·구독자 증감)은 각자 `cold_start_snapshots` 임계와 실제 스냅샷 수를 비교해 준비/수집중을 독립 판정 — 전역 배너 하나로 뭉개지 않는다. 1일차 동작 지표(추천·성과 배수·콘텐츠 갭)는 스냅샷 무관이라 즉시 표시. 급상승 테이블·경쟁 채널·도넛·에버그린의 실 콘텐츠는 6.3~6.6이 채우고, 6.2는 자리·콜드스타트 상태까지.

**목업 라벨 정정(§9).** 목업은 카드 스탯에 "구독자 대비 조회수 N배"를 쓰지만, DESIGN §9·CLAUDE.md가 "성과 배수(채널 평소 대비)"로 정정을 명시했다 — 목업이 아니라 정정 라벨을 따른다(sanctioned 편차, 임의 변경 아님). 편향 2기전은 6.1 `performance_bias_note` 툴팁.

**필터는 쿼리 파라미터·서버 렌더(§6).** 기간 탭·카테고리/유형·평면 토글은 URL 쿼리 파라미터 링크로 서버 렌더(SPA 전환 애니메이션 없음). 근거 보기 펼침만 Stimulus disclosure. 파라미터는 화이트리스트로 검증(오입력 안전 폴백).

## Verification

**Commands:**
- `bin/rails test test/controllers/dashboard_controller_test.rb test/views/dashboard_view_test.rb` -- expected: 전부 통과
- `bin/rails test test/design_tokens_test.rb` -- expected: 토큰 회귀 없음
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/dashboard app/helpers/dashboard_helper.rb` -- expected: 결과 없음
- `grep -rniE "text-(blue|green|red|amber)-[0-9]|bg-(blue|green|red|amber)-[0-9]" app/views/dashboard` -- expected: 원시 색 없음

## Auto Run Result

Status: done

**구현 요약** — `DashboardController#index`(얇게·읽기 전용 AD-3)가 `Recommendation.order(:rank)`·참고 영상(`includes(:video_score, :channel)` 프리로드)·화이트리스트 필터 파라미터·위젯 준비도만 로드한다. 대시보드 홈 뷰가 §4.2 추천 카드(번호 뱃지·기회 점수·근거 보기 Stimulus 펼침)·§4.8 기간 탭·카테고리/유형 드롭다운·밴드/평면 토글·시계열 위젯 콜드스타트 자리(AD-7 위젯별, 전역 배너 금지)를 목업대로 렌더. DESIGN.md §10 토큰만(원시 색 0), "구독자 대비 조회수" 부재·"성과 배수(채널 평소 대비)" 통일, 정직성(자격<3 "N개 확보"·empty·수집 중), 다국어·반응형(본문 가로 스크롤 없음).

**변경/신규 파일**
- `app/controllers/dashboard_controller.rb`(얇은 index)·`app/helpers/dashboard_helper.rb`(신규)
- `app/views/dashboard/index.html.erb`(placeholder 교체)·`_recommendation_card`·`_period_tabs`·`_filter_bar`(신규)
- `app/javascript/controllers/disclosure_controller.js`(신규, eagerLoad 자동등록)
- `test/controllers/dashboard_controller_test.rb`·`test/views/dashboard_view_test.rb`(신규)·`app/assets/builds/tailwind.css`(재빌드)

**리뷰 결과** — Blind + Edge Case 병렬. patch 6(필터 재클릭 string 키 버그·0개 확보 중복·widget COUNT memoize·배수 표기 × 통일·경쟁 영상 존재분 계수·댕글링 펼침 스킵), defer 2(필터의 비디오 테이블 적용 6.3·태그 칩 데이터 소스), reject 2(Config fail-fast·category 라벨 매핑). intent_gap·bad_spec 0. 화면 정합·기능이라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 관련 12 runs/29 assertions, 전체 369 runs/1272 assertions, 0 failures(회귀 없음·design_tokens 그린). 200·읽기 전용·추천 3개/N개 정직성/0개 empty·기간 탭·필터·위젯 콜드스타트 개별·"구독자 대비 조회수" 부재·원시 색 부재 검증. `proposal.html`·`tailwind.config.js`·`scoring.yml` 미변경.

**잔여** — 필터 파라미터의 급상승 테이블 적용·밴드 그룹핑 렌더는 6.3(deferred). 태그 칩 데이터 소스 deferred. 경쟁 채널(6.4)·도넛(6.5)·에버그린(6.6) 실 콘텐츠는 후속. 실 API 호출은 보류(키 대기).
