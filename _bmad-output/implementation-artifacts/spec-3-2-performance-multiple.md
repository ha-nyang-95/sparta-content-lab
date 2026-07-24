---
title: 'Story 3.2: 성과 배수 계산 + 플루크 방어 + 축 분리'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-3-1-baseline-median.md'
warnings: []
baseline_revision: '1daf85e2c185306c7aae752ebf0b3c703aecbbc3'
final_revision: '9517df91f01f30c79768e5d12fb5121afd839a1c'
---

<intent-contract>

## Intent

**Problem:** 규모가 다른 채널의 영상을 raw 조회수로 비교하면 큰 채널이 항상 이긴다. "채널 평소 대비 몇 배"로 환산해야 공정하다 — 단 소수 대박(플루크)이 순위를 흐리지 않게 하한이 필요하다.

**Approach:** `Scoring::CalculatePerformance`(app/services/scoring 경계)가 영상별 **성과 배수 = 현재 누적 view_count ÷ 채널·유형 `Baseline.median_view_count`**를 배치로 계산해 `VideoScore`(video 1:1)로 물질화한다(웹 요청 경로 재계산 없음). 조회수 하한(기준선 상대식) 미만은 순위 부적격, 극단 배수(>임계)는 "검증 요망" 플래그. 성과(배수)와 모멘텀(VPD)을 합산하는 코드 경로는 만들지 않는다(축 분리). 순수 계산·API 무관.

## Boundaries & Constraints

**Always:**
- 채점 로직은 `app/services/scoring` 경계에만(AD-2). 튜닝값(`performance.view_floor_fixed`, `view_floor_k`, `extreme_multiple`)은 `Scoring::Config`로 `config/scoring.yml`에서만 읽는다(AD-4, 하드코딩 금지).
- 성과 배수 = `view_count ÷ Baseline.median_view_count`(해당 채널 + 영상 유형 `is_short?short:long`). float. **배치 물질화** — `VideoScore` 행에 저장하고 웹 요청 경로에서 재계산하지 않는다.
- **퇴화 기준선 방어(3.1 계약 승계):** 해당 Baseline이 없거나 `median_view_count`가 nil 또는 `<= 0`이면 배수를 계산하지 않는다(`performance_multiple` nil·`rank_eligible` false). `Infinity`·`ZeroDivisionError` 절대 발생 금지.
- 조회수 하한 = `max(view_floor_fixed, view_floor_k × median_view_count)` **상대식**. `view_count`가 이 하한 미만이면 `rank_eligible = false`(배수 순위 기본 제외). 고정 절대값 일괄 적용 금지.
- 성과 배수 > `extreme_multiple`이면 `needs_verification = true`("검증 요망 — 외부 요인 가능"). 플래그일 뿐 순위 제외 아님(하한과 독립 축).
- 물질화는 (video) 1:1 유니크로 idempotent 재계산(재실행 시 갱신, 중복 행 금지, AD-5). `is_short` nil(유형 미확정) 영상은 유형 기준선을 못 고르므로 점수 미물질화(행 없음). `view_count` nil은 배수 미계산·`rank_eligible` false(AD-9).

**Block If:**
- (없음 — 순수 로직·기존 스키마·API 무관.)

**Never:**
- 성과 배수와 VPD(모멘텀)를 하나의 종합/합산 점수로 만드는 컬럼·서비스·코드 경로(축 분리, 테스트로 못박음). VPD 입력을 성과 배수 계산에 넣기.
- 고정 절대 하한 일괄 적용(상대식만). 극단 배수 영상을 순위에서 제외(플래그만).
- 웹 요청 경로에서 배수 재계산. 기준선·에버그린 판정(3.1/3.4 담당). 밴드 티어링·정렬(3.3 담당).
- 잡 체인 append(3.4 담당). 화면·컨트롤러.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 정상 배수 | view 1000, 롱폼 기준선 200 | performance_multiple=5.0, rank_eligible=true | — |
| 하한 상대식 | 기준선 5000 → floor=max(300,500)=500; view 400 | rank_eligible=false(400<500) | — |
| 하한 고정 우위 | 기준선 100 → floor=max(300,10)=300; view 250 | rank_eligible=false(250<300) | — |
| 극단 배수 | view 3000, 기준선 100 → 30배 | needs_verification=true, rank_eligible=true | — |
| nil 기준선 | Baseline median nil(표본0) | multiple nil, rank_eligible false | 스킵(예외 없음) |
| 0 기준선 | median 0.0(전량 0뷰) | multiple nil, rank_eligible false | 나눗셈 회피 |
| 기준선 부재 | 해당 유형 Baseline 행 없음 | multiple nil, rank_eligible false | 스킵 |
| nil view | view_count nil(회원전용) | multiple nil, rank_eligible false | AD-9 스킵 |
| is_short nil | 미분류 영상 | VideoScore 미물질화(행 없음) | 유형 미확정 |
| 유형 정합 | 쇼츠는 short 기준선, 롱폼은 long 기준선 | 유형별 올바른 분모 사용 | — |
| 재계산 | 이미 VideoScore 존재 | 같은 행 갱신(중복 없음) | — |
| 축 분리 | 성과·VPD | 두 값을 합산하는 코드 경로 부재 | 구조·테스트로 검증 |

</intent-contract>

## Code Map

- `db/migrate/*_create_video_scores.rb` -- `video_scores`(video_id 유니크, performance_multiple float nullable, rank_eligible bool, needs_verification bool)
- `app/models/video_score.rb` -- `VideoScore`(belongs_to video, 검증)
- `app/services/scoring/calculate_performance.rb` -- `Scoring::CalculatePerformance.new(channel).call` — 유형 기준선 로드·영상별 배수·하한·극단 플래그·물질화
- `app/services/scoring/calculate_baseline.rb` -- 기준선 산출(3.1, 재사용 — 이 서비스가 소비)
- `app/models/baseline.rb`·`app/models/video.rb`·`app/services/scoring/config.rb` -- 기존 재사용
- `config/scoring.yml` -- `performance.*`(기존)
- `test/services/scoring/calculate_performance_test.rb` -- I/O 매트릭스 전 시나리오 + 축 분리
- `test/models/video_score_test.rb` -- video 유니크·검증

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_create_video_scores.rb` -- `create_table :video_scores`: `video`(references, null:false, index), `performance_multiple`(float, null 허용), `rank_eligible`(boolean, null:false, default false), `needs_verification`(boolean, null:false, default false), timestamps. `add_index :video_id, unique: true` -- 영상 1:1·중복 금지 -- `db:migrate && db:prepare`
- [x] `app/models/video_score.rb` -- `VideoScore < ApplicationRecord`: `belongs_to :video`; `validates :video_id, uniqueness: true` -- 물질화 대상 -- 모델 AC
- [x] `app/services/scoring/calculate_performance.rb` -- `Scoring::CalculatePerformance.new(channel).call`: 채널의 `Baseline`을 유형별로 로드(`{"short"=>b, "long"=>b}`) → `is_short` non-nil 영상 각각에 대해 유형 기준선 조회. 기준선 없음/median nil/median<=0/view_count nil이면 `performance_multiple` nil·`rank_eligible` false. 아니면 `multiple = view_count.to_f / median`, `floor = [view_floor_fixed, view_floor_k * median].max`, `rank_eligible = view_count >= floor`, `needs_verification = multiple > extreme_multiple`. `find_or_initialize_by(video:).update!(...)`. 전체를 트랜잭션으로. -- 배수·하한·극단·물질화 AC
- [x] `test/services/scoring/calculate_performance_test.rb`·`test/models/video_score_test.rb` -- I/O 매트릭스 전 시나리오(자사 실측 200~4,100 픽스처, nil/0 기준선 방어, 하한 상대식 두 갈래, 극단 상한, 축 분리=합산 경로 부재) -- 검증

**Acceptance Criteria:**
- Given 기준선이 물질화된 영상, when 성과 배수를 계산하면, then 성과 배수 = 현재 누적 `view_count` ÷ 채널·유형 기준선으로 `VideoScore`에 배치 물질화된다(웹 요청 경로 재계산 없음).
- Given 조회수 하한(`max(고정값, k × 기준선)`) 미만 영상, when 순위 적격을 판정하면, then `rank_eligible = false`로 배수 순위에서 기본 제외된다(고정 절대값 일괄 적용 아님).
- Given 성과 배수가 `extreme_multiple`(25) 초과, when 플래그를 판정하면, then `needs_verification = true`("검증 요망")가 붙되 순위에서 제외되지는 않는다.
- Given 성과 배수(성과)와 VPD(모멘텀), when 코드베이스를 보면, then 둘을 하나의 종합 점수로 합산하는 컬럼·서비스·경로가 존재하지 않는다(별도 축, 테스트로 검증).
- Given 기준선 median이 nil·0이거나 부재이거나 `view_count`가 nil, when 계산하면, then 배수를 계산하지 않고(`performance_multiple` nil·`rank_eligible` false) `Infinity`·`ZeroDivisionError`가 발생하지 않는다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 1: (high 0, medium 0, low 1)
- defer: 1: (medium 1)
- reject: 11: (low 11)
- addressed_findings:
  - `[low]` `[patch]` 하한(`view_count >= floor`)·극단(`multiple > extreme`) 경계값 테스트 부재 — 동작은 스펙대로 정확하나 `view_count == floor`(적격), `multiple == extreme`(플래그 없음) 경계 테스트 2건 추가로 회귀 못박음.
- deferred: (1) 동일 채널 동시 재계산 시 `find_or_initialize_by`+`update!` 경합으로 VideoScore unique(video_id) 위반(RecordNotUnique) — 3.1과 동일 클래스. 잡 병렬화 시 upsert/with_lock 필요(현재 recurring 잡 직렬화라 미도달).
- rejected(noise): view_floor_k Float 강제(Config가 YAML `0.1`을 Float 로드·상대식 테스트가 이미 k≠0 증명), index_by 중복 baseline(3.1 (channel,video_type) 유니크 인덱스로 불가·video_type 도메인 %w[short long] 정확 일치), 배치 단일 트랜잭션 롤백(원자성 의도 — half-scored 방지, 3.4 JobRun 이 실패 로깅), is_short nil 플립 stale 행(AD-8 is_short 1회 확정·불변이라 nil 복귀 불가능), 삭제 영상 orphan(별도 dependent:destroy deferred 기존 항목), 음수 view_count(불가능 상태·CLAUDE.md 규칙2), median<1 폭주(정수 중앙값 최소 0.5·극단 플래그가 정직히 포착), 0.1 float 정밀도 경계(하한은 fuzzy 비즈니스 임계·서브유닛 오차 무의미), N+1/find_each(MVP 채널 영상 수 modest·일일 배치), uniqueness 검증 중복 SELECT(관용·DB 인덱스가 실 가드), needs_verification 부적격 영상 플래그(성과·극단 독립 축 의도·미랭크 시 미노출).

## Design Notes

**물질화 위치.** 성과 배수는 영상 1:1 파생값이라 `video_scores` 별도 테이블에 둔다(3.1 `Baseline`이 `videos`를 오염시키지 않고 별 테이블에 둔 것과 동일 패턴). `videos`는 원천 수집 데이터로 유지(AD-2 채점 파생 분리). 이후 VPD(모멘텀 축)도 성과 축과 물리적으로 분리 — 한 종합 점수로 합칠 유혹을 구조가 차단(축 분리).

**퇴화 기준선 방어.** 3.1이 남기는 두 퇴화 상태(median nil = 표본0, median 0.0 = 전량 0뷰)와 기준선 행 부재·`view_count` nil을 모두 계산 전에 걸러 `performance_multiple` nil·`rank_eligible` false로 물질화한다 — `view_count / 0` 이나 `view_count / nil`에 절대 도달하지 않는다. 이 방어가 3.1 Design Notes '퇴화 기준선 계약'의 소비처다.

**하한은 상대식.** `floor = max(view_floor_fixed, view_floor_k × median)`. 큰 기준선 채널은 상대식(k×기준선)이, 작은 기준선 채널은 고정값이 지배해 자사 정당 대박(200~4,100)을 보호한다. 고정 절대값 일괄 적용은 소형 채널의 진짜 히트를 잘못 걸러내므로 금지.

**축 분리 검증.** `VideoScore`에 종합/합산 점수 컬럼을 두지 않고, `CalculatePerformance`는 `view_count`와 `Baseline`만 입력으로 쓴다(VPD 무관). 테스트가 (1) 배수가 view/기준선의 순수 함수임과 (2) 스키마·서비스에 성과+VPD를 합치는 필드/경로가 없음을 못박는다.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: video_scores 테이블 생성
- `bin/rails test test/services/scoring/calculate_performance_test.rb test/models/video_score_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "c=Channel.first; Scoring::CalculateBaseline.new(c).call; Scoring::CalculatePerformance.new(c).call; p VideoScore.joins(:video).where(videos:{channel_id:c.id}).pluck(:performance_multiple,:rank_eligible,:needs_verification).first(5)"` -- expected: 배수·적격·플래그

## Auto Run Result

Status: done

**구현 요약** — `Scoring::CalculatePerformance.new(channel).call`(app/services/scoring 경계)가 영상별 **성과 배수 = 현재 누적 view_count ÷ 채널·유형 Baseline.median_view_count**를 배치로 계산해 `VideoScore`(video 1:1)로 물질화한다. 조회수 하한 `max(view_floor_fixed, view_floor_k×기준선)` 상대식 미만은 `rank_eligible=false`, 성과 배수 > extreme_multiple 은 `needs_verification=true`(순위 제외 아님·독립 축). 퇴화 기준선(median nil/0·부재)·nil view_count·미분류(is_short nil)는 계산 전 방어 → Infinity·ZeroDivision 없음. 튜닝값은 Scoring::Config로만. VPD와 합산하는 컬럼·경로 없음(축 분리, 테스트로 못박음).

**변경/신규 파일**
- `db/migrate/20260724100009_create_video_scores.rb` — video_scores(video 1:1 유니크)
- `app/models/video_score.rb` — VideoScore(belongs_to video·video_id 유니크)
- `app/services/scoring/calculate_performance.rb` — 배수·하한·극단·퇴화 방어·트랜잭션 물질화
- `test/services/scoring/calculate_performance_test.rb`(16)·`test/models/video_score_test.rb`(3)
- `db/schema.rb` — 마이그레이션 반영

**리뷰 결과** — Blind + Edge Case 병렬. patch 1(하한·극단 경계값 테스트 2건, 동작 불변), defer 1(동시 재계산 경합 — 3.1과 동일), reject 11(view_floor_k Float 강제·index_by 중복·배치 롤백·is_short 플립 stale[AD-8 불가]·음수 view·median<1·float 정밀도·N+1·uniqueness 중복·부적격 플래그 등 — 모두 불가능 상태이거나 이미 방어/테스트됨). intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 19 runs/53 assertions, 전체 192 runs/773 assertions, 0 failures(회귀 없음). 정상 배수·하한 상대식 두 갈래·극단 상한·경계값·nil/0 기준선 방어·유형 정합·idempotent·축 분리(합산 경로 부재)·자사 실측(200~4,100) 검증. `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — 동시 재계산 경합은 deferred(잡 직렬화라 미도달). 밴드 티어링·정렬은 3.3, 잡 체인 append 는 3.4. 튜닝값 잠정(본개발 실측 확정).
