---
title: 'Story 3.1: 기준선(중앙값) 계산 + 신뢰도 하한'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
warnings: []
baseline_revision: 'a5908d79b289aa0746713f3292620a45f4d8b8bc'
final_revision: '189bba5ff0760e52692e42f5b518ca8690aa15d9'
---

<intent-contract>

## Intent

**Problem:** 채널 평소 성과의 기준선이 없다. 평균으로 잡으면 소수 대박 영상이 기준선을 부풀려 이후 성과 배수(3.2)가 규모·플루크에 오염된다.

**Approach:** `Scoring::CalculateBaseline`(app/services/scoring 경계)이 채널·유형(쇼츠/롱폼)별 최근 N개(`scoring.yml`) **공개** 영상 `view_count`의 **중앙값**을 계산해 `Baseline(channel, video_type, median, sample_size, low_confidence)`로 물질화한다. 유형별 표본이 신뢰 하한 미만이면 `low_confidence`로 표시(숨기지 않음). 순수 계산·결정적, API 무관.

## Boundaries & Constraints

**Always:**
- 채점 로직은 `app/services/scoring` 경계에만(AD-2). 튜닝값(`sample_size_n`, `min_sample_for_confidence`)은 `Scoring::Config`로 `config/scoring.yml`에서만 읽는다(AD-4, 하드코딩 금지).
- 기준선은 **중앙값**(평균 아님). 짝수 표본은 가운데 두 값의 평균(float 가능), 홀수는 가운데 값.
- 쇼츠(`is_short=true`)와 롱폼(`is_short=false`)의 중앙값은 **절대 공유하지 않는다** — 유형별 독립 `Baseline` 행.
- 표본 = 유형이 확정된(`is_short` non-nil) + **공개**(`view_count` non-nil) 영상만. `published_at` 내림차순·`id` 내림차순 타이브레이크로 최근 N개(결정적).
- 회원 전용/누락(`view_count` nil) 영상은 표본에서 제외(AD-9).
- 유형별 표본 수가 `min_sample_for_confidence` 미만이면 `low_confidence=true`. 표본 0이면 `median` nil·`sample_size` 0·`low_confidence=true`(다운스트림 nil 방어 계약).
- 물질화는 (channel, video_type) 유니크로 idempotent 재계산(재실행 시 갱신, 중복 행 금지, AD-5).

**Block If:**
- (없음 — 순수 로직·기존 스키마·API 무관. 스텁·키 대기 없음.)

**Never:**
- 평균 사용. 쇼츠·롱폼 표본 혼합. `is_short` nil 영상을 표본에 포함(유형 미확정).
- 성과 배수·하한·에버그린 판정(3.2/3.4 담당). 잡 체인 append(3.4 담당). 웹 요청 경로 계산.
- `view_count` nil을 0으로 치환해 표본에 넣기(공개 영상만 표본).
- 화면·컨트롤러.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 홀수 표본 | 롱폼 공개 5개 view_count | median=가운데 값, sample_size=5 | — |
| 짝수 표본 | 롱폼 공개 4개 | median=가운데 2개 평균(float) | — |
| 유형 미공유 | 쇼츠 3·롱폼 5 | short/long 각각 독립 median 행 | — |
| nil 제외 | 공개 4 + 회원전용(view nil) 2 | 표본 4개로만 median | nil 스킵 |
| 표본 부족 | 유형별 공개 <10 | low_confidence=true(값은 계산) | — |
| 표본 0 | 유형 공개 영상 없음 | median nil, sample_size 0, low_confidence true | 나눗셈·nil 다운스트림 방어 |
| is_short nil | 미분류 영상 존재 | 표본 제외(유형 미확정) | — |
| 재계산 | 이미 Baseline 존재 | 같은 행 갱신(중복 생성 안 함) | — |
| N 상한 | 공개 영상 > N | 최근 N개만(published_at desc·id desc) | — |

</intent-contract>

## Code Map

- `db/migrate/*_create_baselines.rb` -- `baselines` 테이블(channel_id, video_type, median_view_count, sample_size, low_confidence) + (channel_id, video_type) 유니크
- `app/models/baseline.rb` -- `Baseline` 모델(belongs_to channel, VIDEO_TYPES, 검증)
- `app/services/scoring/calculate_baseline.rb` -- `Scoring::CalculateBaseline.new(channel).call` — 유형별 중앙값·표본·저신뢰 계산·물질화
- `config/scoring.yml` -- `baseline.sample_size_n`·`baseline.min_sample_for_confidence`(기존, 재사용)
- `app/services/scoring/config.rb` -- 튜닝값 로더(기존, 재사용)
- `app/models/video.rb` -- 표본 원천(view_count·is_short·published_at, 기존)
- `test/services/scoring/calculate_baseline_test.rb` -- 중앙값·홀짝·유형 미공유·nil 제외·저신뢰·표본0·결정성·idempotent
- `test/models/baseline_test.rb` -- video_type 검증·유니크

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_create_baselines.rb` -- `create_table :baselines`: `channel_id`(FK, null:false), `video_type`(string, null:false), `median_view_count`(float, null 허용), `sample_size`(integer, null:false, default 0), `low_confidence`(boolean, null:false, default true), timestamps. `add_index [:channel_id, :video_type], unique: true` -- 유형별 1행·중복 금지 -- `db:migrate && db:prepare`
- [x] `app/models/baseline.rb` -- `Baseline < ApplicationRecord`: `belongs_to :channel`; `VIDEO_TYPES = %w[short long].freeze`; `validates :video_type, inclusion: {in: VIDEO_TYPES}`; `validates :video_type, uniqueness: {scope: :channel_id}`; `validates :sample_size, numericality: {greater_than_or_equal_to: 0}` -- 물질화 대상 -- 모델 AC
- [x] `app/services/scoring/calculate_baseline.rb` -- `Scoring::CalculateBaseline.new(channel).call`: 각 (video_type, is_short_bool)에 대해 channel.videos에서 `is_short = bool AND view_count IS NOT NULL` 를 `published_at DESC, id DESC` 정렬·`sample_size_n` limit 로 view_count 배열 수집 → `median`(홀짝 처리, 빈 배열이면 nil) → `find_or_initialize_by(channel:, video_type:)` 갱신(median_view_count, sample_size=표본수, low_confidence = 표본수 < min_sample_for_confidence). 두 유형 모두 물질화 -- 계산·물질화 AC
- [x] `test/services/scoring/calculate_baseline_test.rb`·`test/models/baseline_test.rb` -- I/O 매트릭스 전 시나리오(자사 실측 200~4,100 픽스처 포함) -- 검증

**Acceptance Criteria:**
- Given 채널의 공개 영상 표본, when `Scoring::CalculateBaseline`을 실행하면, then 기준선은 채널·유형별 최근 N개(`scoring.yml`) 공개 영상 `view_count`의 중앙값이다(평균 아님).
- Given 계산 결과, when 물질화하면, then `Baseline(channel, video_type, median_view_count, sample_size, low_confidence)` 행으로 저장되고 (channel, video_type) 유니크로 재실행 시 갱신된다.
- Given 쇼츠·롱폼 영상, when 각 유형 기준선을 계산하면, then 두 유형의 중앙값을 절대 공유하지 않는다(독립 행).
- Given 회원 전용(view_count nil) 영상, when 표본을 구성하면, then 표본에서 제외된다.
- Given 유형별 최근 공개 영상이 `min_sample_for_confidence`(10) 미만, when 계산하면, then `low_confidence=true`가 붙는다(값은 계산, 위젯 숨김 없음).
- Given 유형 공개 영상이 0개, when 계산하면, then median nil·sample_size 0·low_confidence true로 안전 물질화된다(다운스트림 nil 방어).

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3: (high 0, medium 2, low 1)
- defer: 2: (medium 2)
- reject: 6: (low 6)
- addressed_findings:
  - `[medium]` `[patch]` `calculate_baseline.rb` 두 유형 `update!`가 트랜잭션 밖 — long 실패 시 short만 갱신된 부분 상태. `Baseline.transaction`으로 원자화(both-or-neither).
  - `[medium]` `[patch]` median 0/nil 계약 미문서화 → 3.2가 `조회수 ÷ 기준선`에서 nil·0 나눗셈 위험. 서비스 주석·스펙 Design Note에 nil/0 퇴화 기준선 방어 계약 명시(값 자체는 진실이라 계산 불변, 3.2가 연속성 승계).
  - `[low]` `[patch]` `median` 반환형 홀수=Integer·짝수=Float 불일치. 홀수 분기 `.to_f`로 통일(항상 Float 계약).
- deferred: (1) is_short nil(미분류) 영상이 두 표본 모두에서 빠져 "데이터 수집 중"을 "저신뢰"로 오표시 — Epic 6 정직성 상태에서 미분류 vs 저신뢰 구분 표시. (2) 동일 채널 동시 재계산 시 `find_or_initialize_by`+`update!` 경합으로 RecordNotUnique(unique index) — 잡 병렬화 시 upsert/with_lock 필요(현재 recurring 잡 직렬화라 미도달).
- rejected(noise): "공개=view_count non-nil" 프록시(스펙 정의·주석됨), sample_size_n<min_confidence 자멸 설정(AD-4 큐레이션값), SQLite published_at NULL 정렬(SQLite 전용·DESC NULLS LAST가 의도 의미), TYPES↔VIDEO_TYPES 이중 소스(2원소 자명), nil-median DB check(과설계·계약 상태), Config.fetch 루프 반복(memoize·frozen).

## Design Notes

**중앙값·결정성.** view_count 오름차순 정렬 후 홀수=가운데, 짝수=가운데 두 값 평균(float). 표본 선택은 `published_at DESC, id DESC`로 결정적(발행 시각 동률도 안정). 발행 시각 정렬은 타임존 무관이라 Asia/Tokyo 경계는 이 계산에 영향 없음(스냅샷 date 경계는 2.x 담당).

**유형 분리·미분류 제외.** `is_short`는 AD-8로 1회 확정·불변. 표본은 `is_short` non-nil(유형 확정) + `view_count` non-nil(공개)만 — 쇼츠/롱폼을 독립 `Baseline` 행으로 물질화해 중앙값을 절대 섞지 않는다. `is_short` nil(미분류)은 유형 미상이므로 표본 제외.

**퇴화 기준선 계약(3.2 나눗셈 방어).** 두 퇴화 상태가 물질화될 수 있다 — (1) 유형 공개 영상 0개면 `median_view_count` nil·`sample_size` 0·`low_confidence` true, (2) 최근 N개 공개 영상이 전량 0 조회수(갓 발행 신생 채널)면 `median_view_count` 0.0(진실한 중앙값). 둘 다 예외로 만들지 않는다 — 3.2 성과 배수(= 조회수 ÷ 기준선)가 **median이 nil 또는 0인 기준선을 나눗셈 전에 방어**해야 한다(nil→스코어링 스킵, 0→하한식 처리). 이 계약은 3.2 스펙이 이전-스토리 연속성으로 승계한다. 컬럼 `median_view_count`가 AC의 `median` 필드다(명확성 위해 view_count 접미).

**물질화.** (channel, video_type) 유니크 + `find_or_initialize_by`로 재계산 idempotent(중복 행 금지, AD-5). 잡 체인 append·전 채널 순회는 3.4가 담당 — 3.1은 채널 1개 서비스까지.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: baselines 테이블 생성
- `bin/rails test test/services/scoring/calculate_baseline_test.rb test/models/baseline_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "c=Channel.first; Scoring::CalculateBaseline.new(c).call; p Baseline.where(channel:c).pluck(:video_type,:median_view_count,:sample_size,:low_confidence)"` -- expected: short/long 2행, 중앙값·표본·저신뢰

## Auto Run Result

Status: done

**구현 요약** — `Scoring::CalculateBaseline.new(channel).call`(app/services/scoring 경계, AD-2)이 채널·유형(쇼츠 is_short=true / 롱폼 false)별 최근 N개(`scoring.yml` baseline.sample_size_n=25) **공개**(view_count non-nil) 영상 view_count의 **중앙값**을 계산해 `Baseline(channel, video_type, median_view_count, sample_size, low_confidence)`로 물질화한다. 쇼츠·롱폼 독립 행(절대 미공유), 표본이 min_sample_for_confidence(10) 미만이면 low_confidence, 표본 0이면 median nil·저신뢰. 튜닝값은 Scoring::Config로만 읽고 하드코딩 없음. 순수 계산·결정적·API 무관.

**변경/신규 파일**
- `db/migrate/20260724100008_create_baselines.rb` — baselines 테이블((channel,video_type) 유니크)
- `app/models/baseline.rb` — Baseline(video_type 화이트리스트·유니크·sample_size≥0)
- `app/services/scoring/calculate_baseline.rb` — 중앙값·표본·저신뢰 계산·트랜잭션 물질화
- `test/services/scoring/calculate_baseline_test.rb`(13)·`test/models/baseline_test.rb`(5)
- `db/schema.rb` — 마이그레이션 반영

**리뷰 결과** — Blind + Edge Case 병렬. patch 3(트랜잭션 원자화·nil/0 퇴화 기준선 계약 문서화·median .to_f 통일), defer 2(미분류 vs 저신뢰 정직성 표시 — Epic 6, 동시 재계산 경합 — 잡 병렬화 시), reject 6(공개 프록시·config 자멸·SQLite NULL 정렬·이중 소스·nil DB check·fetch 반복). intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 18 runs/50 assertions, 전체 173 runs/720 assertions, 0 failures(회귀 없음). 홀짝 중앙값·유형 미공유·nil 제외·저신뢰·표본0·idempotent·N상한·id-desc 타이브레이크·자사 실측(200~4,100) 픽스처 검증. `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — median 0/nil 퇴화 기준선은 3.2가 나눗셈 방어(계약 명시, 연속성 승계). 미분류·동시경합은 deferred. 키워드·튜닝값 잠정(본개발 실측 확정).
