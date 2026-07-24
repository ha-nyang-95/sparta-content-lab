---
title: 'Story 3.3: 구독자 밴드 티어링 + 결정적 정렬키'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-3-2-performance-multiple.md'
warnings: []
baseline_revision: '90accc3c7b37d748c6cd5199914d1cb538099776'
final_revision: 'dd44637b8c0297d74517e5a96b2ec8a1e4522d30'
---

<intent-contract>

## Intent

**Problem:** 결과를 raw 조회수로 정렬하면 큰 채널이 상단을 독식하고 소형 채널의 대박이 묻힌다. 구독자 규모로 그룹핑하고 밴드 내에서 성과 배수로 정렬해야 소형 채널의 히트가 자기 슬롯에서 드러난다.

**Approach:** `Scoring::SubscriberBand`(app/services/scoring 경계)가 `Channel.subscriber_count`를 `scoring.yml`의 `subscriber_bands`로 4티어로 분류한다(밴드는 필터·그룹핑 축, 배수 분모 아님). `VideoScore.ranked` 스코프가 기본 정렬키를 **성과 배수 내림차순 + 결정적 타이브레이크**로 제공한다(raw 조회수 정렬 금지). 밴드는 subscriber_count의 순수 함수라 컬럼으로 물질화하지 않고 계산한다. 표시·평면 토글은 Epic 6.

## Boundaries & Constraints

**Always:**
- 채점·분류 로직은 `app/services/scoring` 경계에만(AD-2). 밴드 경계값은 `Scoring::Config`로 `config/scoring.yml`의 `subscriber_bands`에서만 읽는다(AD-4, 하드코딩 금지).
- 밴드 4티어 = `<1만 / 1만~10만 / 10만~50만 / 50만+`. 임계값은 **포함 하한**(count가 임계 이상이면 상위 티어). 정수 티어 인덱스 `0..3`으로 표현(로케일 무관·정렬 가능), 라벨은 표시용 상수로 별도 제공.
- 밴드는 `subscriber_count`의 순수 함수 — **DB 컬럼으로 물질화하지 않는다**(구독자 수가 매일 갱신되므로 파생 컬럼은 동기화 위험). `Scoring::SubscriberBand`로 계산하고 `Channel#subscriber_band`가 위임한다.
- 밴드는 **필터·그룹핑 축**일 뿐 성과 배수 계산에 절대 들어가지 않는다(배수 분모는 3.2 기준선 유지, 축 분리).
- 기본 정렬키 `VideoScore.ranked` = `performance_multiple` **내림차순** + 결정적 타이브레이크(`video_id` 오름차순). **raw `view_count` 기본 정렬 금지**. `rank_eligible = false`(하한 미만·nil 배수) 영상은 기본 순위에서 제외(3.2 rank_eligible 게이트 승계).
- `subscriber_count` nil 방어(AD-9): 밴드 미상(`nil` 티어) 반환 — 예외 없음.

**Block If:**
- (없음 — 순수 로직·기존 스키마·API 무관. 마이그레이션 불필요.)

**Never:**
- 밴드를 성과 배수의 분모로 사용. 밴드를 DB 컬럼으로 물질화(동기화 위험). raw 조회수를 기본 정렬키로.
- 화면·컨트롤러·표시 토글(Epic 6 담당). 에버그린·잡 체인 append(3.4 담당).
- 밴드 경계 하드코딩. 비결정적 정렬(타이브레이크 없는 order).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 티어0 | subscriber 9,999 | tier 0 (<1만) | — |
| 티어 경계 1만 | subscriber 10,000 | tier 1 (1만~10만, 포함 하한) | — |
| 티어 경계 10만 | subscriber 100,000 | tier 2 (10만~50만) | — |
| 티어 경계 50만 | subscriber 500,000 | tier 3 (50만+) | — |
| 티어3 상단 | subscriber 2,000,000 | tier 3 | — |
| subscriber nil | subscriber_count nil | tier nil(밴드 미상) | AD-9 방어 |
| 정렬 배수 desc | 배수 2·5·3 | ranked: 5,3,2 순 | — |
| 정렬 raw 아님 | view 큰 순 ≠ 배수 큰 순 | 배수 기준 정렬(조회수 아님) | — |
| 타이브레이크 | 배수 동률 | video_id 오름차순 결정적 | — |
| 부적격 제외 | rank_eligible=false / nil 배수 | ranked 에서 제외 | — |

</intent-contract>

## Code Map

- `app/services/scoring/subscriber_band.rb` -- `Scoring::SubscriberBand`(tier 계산·라벨 상수, config 경계)
- `app/models/channel.rb` -- `#subscriber_band` 위임(기존 파일에 메서드 추가)
- `app/models/video_score.rb` -- `ranked` 스코프(배수 desc·결정적 타이브레이크, 기존 파일에 스코프 추가)
- `app/services/scoring/config.rb` -- `subscriber_bands` 로더(기존 재사용)
- `config/scoring.yml` -- `subscriber_bands: [10000, 100000, 500000]`(기존)
- `test/services/scoring/subscriber_band_test.rb` -- 4티어 경계값·nil 방어
- `test/models/channel_test.rb`·`test/models/video_score_test.rb` -- `#subscriber_band` 위임·`ranked` 정렬·타이브레이크·부적격 제외·raw 아님

## Tasks & Acceptance

**Execution:**
- [x] `app/services/scoring/subscriber_band.rb` -- `Scoring::SubscriberBand`: `LABELS = ["<1만","1만~10만","10만~50만","50만+"].freeze`; `def self.tier(subscriber_count)` → nil이면 nil, 아니면 `Scoring::Config.fetch(:subscriber_bands).count { |threshold| subscriber_count >= threshold }`(포함 하한, 0..3); `def self.label(count)` → tier로 LABELS 조회(nil이면 "미상"/nil) -- 밴드 계산 AC
- [x] `app/models/channel.rb` -- `def subscriber_band; Scoring::SubscriberBand.tier(subscriber_count); end`(순수 위임, 컬럼 없음) -- 밴드 축 AC
- [x] `app/models/video_score.rb` -- `scope :ranked, -> { where(rank_eligible: true).order(performance_multiple: :desc, video_id: :asc) }` -- 기본 정렬키 AC
- [x] `test/services/scoring/subscriber_band_test.rb`·`test/models/channel_test.rb`·`test/models/video_score_test.rb` -- I/O 매트릭스 전 시나리오(경계값 정확히 1만/10만/50만, 배수 desc, raw 조회수 정렬 아님, 동률 타이브레이크, 부적격 제외, subscriber nil) -- 검증

**Acceptance Criteria:**
- Given 성과 배수가 계산된 영상들, when 구독자 밴드를 산출하면, then 4티어(<1만/1만~10만/10만~50만/50만+)가 `subscriber_count`로 계산되고 밴드는 필터·그룹핑 축이지 배수 분모가 아니다.
- Given 정렬, when 기본 정렬키를 적용하면, then `performance_multiple` 내림차순이 기본이며 raw `view_count` 기본 정렬이 아니다.
- Given 성과 배수 동률, when 정렬하면, then `video_id` 오름차순으로 결정적으로 정렬된다(안정적).
- Given `rank_eligible=false`이거나 배수 nil인 영상, when 기본 순위를 산출하면, then `ranked`에서 제외된다.
- Given `subscriber_count`가 nil, when 밴드를 산출하면, then 예외 없이 밴드 미상(nil 티어)을 반환한다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 2: (high 0, medium 1, low 1)
- defer: 0
- reject: 6: (low 6)
- addressed_findings:
  - `[medium]` `[patch]` `subscriber_band.rb` LABELS(4개 하드코딩)와 `subscriber_bands`(AD-4 튜닝 가능) 커플링 무방비 — 밴드 개수 변경 시 `tier`가 인덱스 초과해 `LABELS[t]=nil`을 조용히 반환. `ensure_labels_cover!` fail-fast(`LABELS.length == bands.length+1` 위반 시 KeyError, Discovery::Config fail-fast 패턴 정합) + 불변식 테스트 추가.
  - `[low]` `[patch]` `video_score.rb` `ranked`가 nil 배수 제외를 3.2 불변식(nil 배수→rank_eligible false)에만 의존 — 불변식 위반 데이터가 SQLite에서 NULL-last로 조용히 하단 랭크. `.where.not(performance_multiple: nil)` 방어 추가(어댑터 무관) + 방어 테스트.
- rejected(noise): 중복 임계값 tier 부풀림(malformed 큐레이션 config), 빈 bands 전량 tier0(동일), 음수/NaN/String subscriber(불가능 상태·AD-9는 nil만 방어·CLAUDE.md 규칙2), `VideoScore.ranked` 전역 cross-channel(의도된 조합성 — Epic 6가 channel join·group), video_id 유니크 의존 타이브레이크(VideoScore 1:1 유니크 인덱스·검증으로 보장), 라벨 문자열 값 드리프트(임계 값 재튜닝 시 라벨 부정확 — 표시 문자열은 Epic 6 관심사·길이 가드가 구조 정합 확보).

## Design Notes

**밴드는 계산, 물질화 안 함.** 밴드는 `subscriber_count` 단일 컬럼의 O(1) 임계 분류다. 3.1 `Baseline`·3.2 `VideoScore`가 값비싼 집계라 물질화한 것과 달리, 밴드를 파생 컬럼으로 두면 매일 갱신되는 구독자 수와 동기화해야 하는 부채만 생긴다. `Scoring::SubscriberBand.tier`로 계산하고 `Channel#subscriber_band`가 위임한다. 경계는 `bands.count { |t| count >= t }` — 포함 하한을 우아하게 표현(정확히 1만→티어1, 10만→티어2, 50만→티어3).

**정렬은 배수 desc.** `VideoScore.ranked = where(rank_eligible: true).order(performance_multiple: :desc, video_id: :asc)`. `rank_eligible: true` 필터가 3.2 하한 게이트를 승계해 nil 배수·하한 미만을 제외하므로 `performance_multiple`는 항상 non-nil(NULL 정렬 문제 없음). `video_id` 오름차순 타이브레이크로 배수 동률도 결정적(AD-15). raw `view_count`는 정렬키에 절대 넣지 않는다 — 규모 편향 방지가 제품 핵심.

**밴드 vs 정렬 분리.** 밴드(그룹핑 축)와 정렬(배수 축)은 독립 산출물이다. Epic 6 표시가 `VideoScore.ranked.joins(video: :channel)`을 `channel.subscriber_band`로 그룹핑해 조합한다 — 3.3은 두 조각을 제공하고 밴드를 배수 계산에 섞지 않는다(축 분리).

## Verification

**Commands:**
- `bin/rails test test/services/scoring/subscriber_band_test.rb test/models/channel_test.rb test/models/video_score_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "p [0,9999,10000,100000,500000,2_000_000,nil].map { |n| Scoring::SubscriberBand.tier(n) }"` -- expected: `[0,0,1,2,3,3,nil]`

## Auto Run Result

Status: done

**구현 요약** — `Scoring::SubscriberBand.tier(count)`가 `subscriber_count`를 `scoring.yml`의 `subscriber_bands`로 4티어(0..3, 포함 하한 `bands.count { |t| count >= t }`)로 분류하고 nil은 밴드 미상(nil). `Channel#subscriber_band`가 위임(파생 컬럼 없이 계산 — 매일 갱신되는 구독자 수 동기화 부채 회피). `VideoScore.ranked` 스코프가 기본 정렬키를 `performance_multiple` 내림차순 + `video_id` 오름차순 결정적 타이브레이크로 제공(raw 조회수 정렬 금지·rank_eligible/nil 배수 제외). 밴드는 그룹핑 축일 뿐 배수 분모 아님(축 분리). 마이그레이션 없음.

**변경/신규 파일**
- `app/services/scoring/subscriber_band.rb`(신규) — tier·label·config 커플링 fail-fast 가드
- `app/models/channel.rb` — `#subscriber_band` 위임 메서드 추가(기존 검증·스코프 불변)
- `app/models/video_score.rb` — `ranked` 스코프 추가(nil 배수 방어 포함)
- `test/services/scoring/subscriber_band_test.rb`(신규)·`test/models/channel_test.rb`·`test/models/video_score_test.rb`(추가)

**리뷰 결과** — Blind + Edge Case 병렬. patch 2(LABELS↔bands 길이 커플링 fail-fast·ranked nil 배수 방어), defer 0, reject 6(중복/빈 config·음수/NaN subscriber·전역 스코프 조합성·video_id 유니크 보장·라벨 값 드리프트 — 불가능 상태이거나 의도/보장됨). intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 마이그레이션 없음. 관련 28 runs/40 assertions, 전체 209 runs/792 assertions, 0 failures(회귀 없음). 티어 매핑 `[0,0,1,2,3,3,nil]`·경계값 정확히 1만/10만/50만·배수 desc 정렬·raw 조회수 아님·동률 video_id 타이브레이크·부적격/nil 제외·LABELS 불변식 검증. `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — 라벨 문자열 값은 임계 재튜닝 시 부정확할 수 있음(표시 문자열은 Epic 6 관심사, 길이 가드가 구조 정합 보장). 표시·평면 토글·밴드 그룹핑 조합은 Epic 6. 튜닝값 잠정(본개발 실측 확정).
