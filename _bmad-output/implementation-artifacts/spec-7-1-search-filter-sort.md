---
title: 'Story 7.1: 검색 · 필터 · 정렬 (인기 콘텐츠 확장)'
type: 'feature'
created: '2026-07-25'
status: 'done'
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-3-popular-videos-table.md'
  - '{project-root}/DESIGN.md'
warnings: []
baseline_revision: '600374426c6a36c8a7d0bc10c65e96dcfe452ab8'
final_revision: '13ed0ee04ab85b2f763298924c68a2dbcc34a47d'
---

<intent-contract>

## Intent

**Problem:** 인기 콘텐츠(6.3)는 기간·카테고리·유형·레이아웃만 필터한다. 운영자가 키워드·채널·조회수·성과 배수·구독자 밴드로 좁히고 정렬 기준을 바꿔 원하는 영상을 빠르게 찾을 수단이 없다(FR-25).

**Approach:** 좌측 내비는 6화면 고정(검색 전용 내비 없음)이므로 **인기 콘텐츠 화면(6.3)에 검색·추가 필터·정렬을 얹는다**(의존 6.3). `PopularController` 를 얇은 읽기 전용(AD-3) 유지한 채, 물질화 컬럼을 화이트리스트 파라미터로 쿼리·정렬만 확장 — 키워드(제목 LIKE)·채널·조회수·성과 배수 프리셋(2/3/5/10/25)·구독자 밴드 필터 + 정렬(배수/조회수/최신) 선택. 6.2/6.3 화이트리스트·string 키 쿼리 병합 규약 재사용.

## Boundaries & Constraints

**Always:**
- **읽기 전용**(AD-3) — 물질화된 `VideoScore`(rank_eligible·performance_multiple)·`videos`·`channels` 컬럼을 쿼리·정렬만. 재계산 금지(P95 2초). 기존 6.3 base(`rank_eligible: true` + `performance_multiple` non-nil + `channels.excluded: false`) 유지.
- **검색(키워드)** — `q` 파라미터 → `videos.title LIKE` **파라미터라이즈 + `sanitize_sql_like`** (`%`·`_` 이스케이프, SQL 인젝션 방어). 대소문자 무시. 다국어(§7) — 한·일 제목 그대로 부분일치. 공백/빈 문자열이면 미적용. 길이 상한(예 100자)으로 방어.
- **필터 차원**(전부 화이트리스트·오입력 폴백) — 기간(period, 기존)·카테고리(category, 기존)·유형(type long/short, 기존·**쇼츠/롱폼 분리 유지**)·레이아웃(layout, 기존)에 더해: **채널**(`channel` = Channel.id, not_excluded 목록 화이트리스트, "전체" 기본)·**성과 배수 프리셋**(`min_multiple` ∈ scoring.yml `multiple_presets` [2,3,5,10,25] → `performance_multiple >= preset`, "전체" 기본)·**구독자 밴드**(`band` ∈ 0..3 → `channels.subscriber_count` 범위, 임계는 scoring.yml `subscriber_bands`, "전체" 기본).
- **정렬**(`sort` 화이트리스트, 결정적 타이브레이크 `video_id: :asc`) — `multiple`(성과 배수 desc, 기본·6.3 동작 보존)·`views`(조회수 desc nulls last)·`recent`(published_at desc nulls last). `ranked` 고정 정렬 대신 base + 선택 정렬로 리팩터(6.3 기본 동작 불변).
- **파라미터 병합** — 드롭다운/정렬은 `request.query_parameters.merge(string 키)` 링크(6.2 수정 규약 — symbol 키 금지). 검색 폼(GET)은 다른 활성 필터를 hidden input 으로 보존(검색이 기간·정렬 등을 리셋하지 않음).
- 색 **DESIGN §10 토큰만**(AD-15). 검색바·드롭다운 §4.8. 라벨 "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**. 반응형(§5, 컨트롤 모바일 스택·표 가로 스크롤·본문 가로 스크롤 금지)·다국어(§7)·nil 방어(AD-9). 결과 0건 empty·loading·정직성. N+1 프리로드(`includes(video: [:channel, :daily_stats])`) 유지.

**Block If:**
- (없음 — FR-25·6.3 의존·고정 6나비로 호스트=인기 콘텐츠 확정. 필터 차원·프리셋은 AC·scoring.yml 로 확정.)

**Never:**
- 웹 요청 경로 재계산(물질화 쿼리만). 원시 SQL 문자열 보간(검색어는 파라미터라이즈+sanitize_sql_like). 쇼츠/롱폼 혼합. 원시 Tailwind 색. "구독자 대비 조회수". 6.3 쿼리 base(rank_eligible)·컬럼·_video_row 변경. 검색이 다른 필터 리셋. 새 내비/화면.
- 저장/북마크(7.2). 페이지네이션(범위 밖 — 기존 6.3 전량 로드 유지).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 키워드 | q="조사" | title LIKE %조사% (이스케이프) | 빈/공백 → 미적용 |
| 키워드 특수문자 | q="100%_a" | %·_ 이스케이프, 리터럴 매치 | 인젝션 방어 |
| 채널 필터 | channel=<id> | 그 채널만 | 미존재/오입력 → 전체 |
| 배수 프리셋 | min_multiple=5 | performance_multiple≥5 | 프리셋 외 → 전체 |
| 밴드 필터 | band=2 | subscriber_count 10만~50만 | 0..3 외 → 전체 |
| 유형 | type=short | 쇼츠만(분리) | — |
| 정렬 배수 | sort=multiple(기본) | 배수 desc, id asc | — |
| 정렬 조회수 | sort=views | view_count desc nulls last | — |
| 정렬 최신 | sort=recent | published_at desc nulls last | — |
| 복합 | q+channel+min_multiple+sort | 모두 AND 적용 | — |
| 검색 폼 | 제출 | 다른 필터 hidden 보존 | — |
| 0건 | 조건 부합 없음 | empty 상태 | — |
| 읽기 전용 | GET | VideoScore 쓰기 없음 | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |
| 모바일 | 좁은 뷰포트 | 컨트롤 스택·표 스크롤 | — |

</intent-contract>

## Code Map

- `app/helpers/dashboard_helper.rb` -- (추가) `SORTS`·`multiple_options`·`band_options`; `permitted_sort`·`permitted_min_multiple`·`permitted_band`·`search_query`(길이 상한·strip) 화이트리스트 헬퍼.
- `app/controllers/popular_controller.rb` -- (수정) 신규 파라미터 읽기 + `apply_filters` 에 q(LIKE)·channel·min_multiple·band 추가 + `ranked` 고정 정렬 → base+`apply_sort`. `@channels`(드롭다운) 로드. 읽기 전용 유지.
- `app/views/popular/index.html.erb` -- (수정) 검색바(§4.8, GET 폼·hidden 필터 보존) + 필터 바에 채널·배수·밴드·정렬 드롭다운 추가. 표·_video_row 불변.
- `app/views/popular/_search_bar.html.erb`·`_sort_dropdown.html.erb` -- (신규, 선택) §4.8 컨트롤 분리.
- `config/scoring.yml` -- `multiple_presets`·`subscriber_bands`(기존).
- `test/controllers/popular_controller_test.rb`·`test/helpers/dashboard_helper_test.rb` -- 검색·필터·정렬·화이트리스트·인젝션 방어·읽기 전용·N+1

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/dashboard_helper.rb` -- `SORTS = [%w[multiple 배수\ 높은순], %w[views 조회수\ 높은순], %w[recent 최신순]]`; `multiple_options` = `[["all","전체"]] + Scoring::Config.fetch(:performance, :multiple_presets).map { |m| [m.to_s, "#{m}배+"] }`; `band_options` = `[["all","전체"],["0","1만 미만"],["1","1만~10만"],["2","10만~50만"],["3","50만+"]]`; `permitted_sort(params)`(SORTS 화이트, 기본 "multiple")·`permitted_min_multiple(params)`(multiple_options 키 화이트, 기본 "all")·`permitted_band(params)`(band_options 키 화이트, 기본 "all")·`search_query(params)`(`params[:q].to_s.strip[0,100]`) -- 헬퍼 AC
- [ ] `app/controllers/popular_controller.rb` -- 신규 ivar `@q/@channel/@min_multiple/@band/@sort` = 헬퍼; `@channels = Channel.not_excluded.order(:name)`; base = `VideoScore.where(rank_eligible: true).where.not(performance_multiple: nil).joins(video: :channel).where(channels: { excluded: false })`; `apply_filters` 확장 — period/category/type(기존) + `@q.present?` → `where("videos.title LIKE ?", "%#{Video.sanitize_sql_like(@q)}%")`(대소문자 무시) + `@channel` 유효 id → `where(videos: { channel_id: @channel })` + `@min_multiple != "all"` → `where("video_scores.performance_multiple >= ?", @min_multiple.to_f)` + `@band != "all"` → subscriber_count 범위(scoring.yml subscriber_bands 임계); `apply_sort(scope)` — sort=views→`order(Arel.sql("videos.view_count DESC NULLS LAST"))`·recent→`order(Arel.sql("videos.published_at DESC NULLS LAST"))`·else 배수 desc, 모두 `.order(video_id: :asc)`; `@scores = scope.includes(video: [:channel, :daily_stats]).to_a`; 밴드 그룹핑(layout=band) 유지. **계산·쓰기 없음** -- 컨트롤러 AC
- [ ] `app/views/popular/index.html.erb` -- 검색바(GET 폼 action=popular_path, `q` text input + 제출, 현재 period/category/type/layout/sort/channel/min_multiple/band 를 hidden input 으로 보존) + 필터 바 확장(채널·배수·밴드·정렬 드롭다운 — `_filter_bar` 패턴 재사용·string 키 병합). 표·헤더·`_video_row` 불변. §10·§7·§5 -- 화면 AC
- [ ] `test/controllers/popular_controller_test.rb`·`test/helpers/dashboard_helper_test.rb` -- 키워드 검색(부분일치·특수문자 이스케이프·인젝션 무해)·채널 필터·배수 프리셋(≥)·밴드 범위·유형 분리·정렬 3종 결정성(배수/조회수/최신 + 타이브레이크)·화이트리스트 폴백(오입력→전체/기본)·복합 필터·검색 폼 hidden 보존·0건 empty·GET 읽기 전용·"구독자 대비 조회수" 부재·원시 색 부재·N+1 프리로드 -- 검증

**Acceptance Criteria:**
- Given 물질화된 영상·배수 값, when 키워드·채널·유형·기간·조회수·성과 배수·구독자 밴드로 검색·필터·정렬하면, then 물질화 컬럼 쿼리로 좁혀지고 정렬되며 웹 요청 경로에서 재계산하지 않는다.
- Given 성과 배수 프리셋(2x/3x/5x/10x/25x), when 하나를 고르면, then 그 배수 이상 영상만 남는다.
- Given 유형 필터, when 쇼츠/롱폼을 고르면, then 두 유형이 분리 유지된다.
- Given 검색어에 `%`·`_`·따옴표가 있을 때, when 검색하면, then 리터럴로 이스케이프되어 매치되고 SQL 인젝션이 되지 않는다.
- Given 여러 필터, when 검색 폼을 제출하면, then 기존 필터·정렬이 리셋되지 않고 보존된다.
- Given 조건 부합 0건, when 보면, then empty 상태가 표시되고 좁은 화면에서 컨트롤이 스택되며 본문이 가로로 깨지지 않는다.
- Given GET 요청, when 처리하면, then VideoScore 를 쓰지 않는다(읽기 전용, AD-3).

## Design Notes

**호스트 = 인기 콘텐츠(고정 6나비).** 검색 전용 내비가 없고 의존이 6.3이라, 7.1은 인기 콘텐츠 리스트에 검색·필터·정렬을 얹는다. 6.3의 base(rank_eligible)·컬럼·_video_row·밴드 그룹핑은 불변, 필터·정렬 차원만 확장.

**정렬 리팩터 — 6.3 동작 보존.** `VideoScore.ranked`(배수 desc 고정)를 base + `apply_sort` 로 분리하되 기본 sort=multiple 은 기존과 동일(배수 desc, video_id asc). views/recent 는 nulls last + 타이브레이크로 결정적.

**검색·밴드는 물질화 쿼리(AD-3).** 제목 LIKE·subscriber_count 범위·performance_multiple 임계는 저장 컬럼 조건일 뿐 재계산 아님. 검색어는 `sanitize_sql_like` + 파라미터라이즈로 인젝션·와일드카드 오남용 방어. 밴드 필터는 subscriber_bands 임계로 범위 변환(SubscriberBand.tier 와 동일 경계).

**화이트리스트·파라미터 보존.** 모든 신규 파라미터는 DashboardHelper 화이트리스트로 오입력을 기본값 폴백. 드롭다운은 string 키 병합(6.2 수정), 검색 폼은 hidden 으로 필터 보존.

## Review Triage Log

이중 적대 리뷰(Blind Hunter + Edge Case Hunter). 두 리뷰어가 **SQL 인젝션·6.3 회귀·밴드 경계·ESCAPE·정렬 결정성을 실증으로 CLEARED**.

**실증으로 기각(정상)**
- **SQL 인젝션 없음** — `@q` 는 bind value(`"%#{sanitize_sql_like(@q)}%"` + `ESCAPE ?`)로만 전달, SQL 조각 아님. `q="100%"` → 리터럴 매치(`1000` 미매치) 실증. channel(화이트리스트 bind)·min_multiple(.to_f)·band(config 정수)·sort(하드코딩 Arel) 전부 파라미터라이즈.
- **6.3 회귀 없음** — 기본 sort=multiple + 새 base 가 구 `VideoScore.ranked`(rank_eligible·non-nil·excluded:false·배수 desc·video_id asc)와 동일 WHERE/ORDER 실증. 밴드 그룹핑 불변.
- **밴드 경계 정확** — subscriber_count 10000→티어1·100000→티어2·500000→티어3, SubscriberBand.tier 와 완전 일치. nil 구독자는 모든 밴드에서 제외(band=all 만 노출) = tier(nil) 정합.
- **ESCAPE·대소문자·정렬 NULLS LAST·타이브레이크·N+1·XSS·화이트리스트 폴백(Array/Hash 파라미터 포함)** 전부 실증 정상.

**패치(적용)**
1. **[Minor·정직성] empty 상태가 필터-0건을 콜드스타트로 오표시** — 데이터가 있는데 필터가 0건이어도 "데이터 수집 중"(§4.7 콜드스타트)로 보였다. → `@has_any_scores`(필터 무관 존재 EXISTS) 로 분기: 데이터 있으면 "검색·필터 조건에 맞는 영상이 없습니다", 스코어 자체가 없으면 콜드스타트. 회귀 테스트 2건.
2. **[Low·UX] `@channel` 미정규화 → 오입력 시 드롭다운 라벨 공백·값 영속** — `?channel=999999` 가 필터는 폴백되나 라벨 nil·hidden/링크에 잔존. → index 에서 @channels 로드 후 유효 id 아니면 ""(전체)로 정규화. apply_filters 채널 검증 단순화. 회귀 테스트 1건.
3. **[Low] 밴드 그룹 내 정렬 주석 낡음** — "밴드 내 ranked(배수 desc) 유지" → apply_sort(@sort) 결과 유지로 정정.
4. **[Nit] search_query 죽은 `.to_s` 제거**(String#[] 0 인덱스는 nil 불가).
5. **[drift 방어] band_options 티어 수 ↔ subscriber_bands 임계 수 락스텝 테스트** — AD-4 튜닝으로 임계 수 바뀌면 컨트롤러 `t[없는 인덱스]=nil` 팬텀 티어 → 조용히 0매치. 카운트 가드 테스트로 포착.

**Defer(문서화)**
- `<details>` 드롭다운 a11y(외부 클릭 미닫힘 등) — 6.2 filter_bar 기존 패턴, 재설계 범위 밖.
- ESCAPE bind-param(vs 리터럴) — SQLite 동작·테스트 그린, 포터빌리티 nit.
- ASCII 한정 대소문자 무시 — KR/JP 무관(케이스 없음).
- 밴드 라벨 하드코딩 — 임계 튜닝 시 라벨도 갱신 필요(카운트 가드로 팬텀 티어는 방지, 라벨은 운영자 갱신).

**추가 테스트(회귀 방지)** — 컨트롤러 3건(필터-empty vs 콜드스타트·channel 정규화), 헬퍼 1건(band 락스텝). 전 스위트 480 runs 0 failures.

## Verification

**Commands:**
- `bin/rails test test/controllers/popular_controller_test.rb test/helpers/dashboard_helper_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/popular app/helpers/dashboard_helper.rb` -- expected: 결과 없음
- `grep -rniE "(text|bg|border)-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-[0-9]" app/views/popular` -- expected: 원시 색 없음

## Auto Run Result

Status: done

- **구현**: 인기 콘텐츠(6.3) 화면에 검색·필터·정렬 확장(고정 6나비 → 검색 전용 화면 없음). 얇은 읽기 전용(AD-3) PopularController — 키워드(제목 LIKE + sanitize_sql_like + ESCAPE)·채널·성과 배수 프리셋(≥)·구독자 밴드(subscriber_count 범위)·유형(쇼츠/롱폼 분리) 필터 + 정렬(배수/조회수/최신, 결정적 타이브레이크). DashboardHelper 화이트리스트·string 키 병합·검색 폼 hidden 보존.
- **리뷰**: 이중 적대 리뷰 — SQL 인젝션·6.3 회귀·밴드 경계·ESCAPE·정렬 결정성 실증 CLEARED. 패치 5건(empty 정직성 분기·channel 정규화·주석·죽은코드·band 락스텝), 4건 defer.
- **테스트**: `bin/rails test` — **480 runs, 1660 assertions, 0 failures, 0 errors, 0 skips**(회귀 +3). grep — 금지 라벨·원시 색 부재.
