---
title: 'Story 3.4: 에버그린 후보 판정(대리지표, 1일차) + 스코어링 스테이지 체인 append'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-3-2-performance-multiple.md'
warnings: []
baseline_revision: 'b6d536f3f8020881e8076241aaa62a680b35c3cd'
final_revision: 'b168323713801362ffa9c2eaad9b36c5558eb804'
---

<intent-contract>

## Intent

**Problem:** 오래됐는데 채널 평소 대비 배수가 높은 영상(검색 유입형)을 1일차부터 발견해야 한다. 또 Epic 3 스코어링(기준선→성과 배수→에버그린)이 아직 일일 잡에 연결되지 않아 배치로 물질화되지 않는다.

**Approach:** `Scoring::DetermineEvergreen`(app/services/scoring 경계)이 나이(경과일 ≥ `min_age_days`) **AND** 성과 배수(≥ `min_multiple`) 두 임계 동시 충족을 스냅샷 없이 현재 조회수·`published_at`·기준선(=성과 배수)만으로 판정해 `VideoScore.evergreen_candidate`로 물질화한다("에버그린 후보" 라벨, "에버그린" 단정 아님). 그리고 스코어링 스테이지(기준선→성과 배수→에버그린)를 `DailyCollectionJob` 체인의 스냅샷 저장 뒤에 순서대로 append한다(잡은 조립만, 각 스테이지는 이전 산출을 DB에서 읽어 다음을 씀, AD-11). 순수 계산·API 무관.

## Boundaries & Constraints

**Always:**
- 판정 로직은 `app/services/scoring` 경계에만(AD-2). 임계값(`evergreen.min_age_days`, `evergreen.min_multiple`)은 `Scoring::Config`로 `config/scoring.yml`에서만 읽는다(AD-4, 하드코딩 금지).
- 에버그린 후보 = 나이 임계 **AND** 배수 임계 **동시 충족**: `age_days >= min_age_days` **그리고** `performance_multiple >= min_multiple`. **배수 > 1을 후보 기준으로 쓰지 않는다**.
- 스냅샷 없이 판정(1일차 동작): 현재 `view_count`·`published_at`·기준선만 사용. 성과 배수는 3.2 `VideoScore.performance_multiple`(= view ÷ 기준선)를 읽는다 — 별도 재계산·스냅샷 이력 불요.
- 경과일은 **Asia/Tokyo 경계**로 계산: `Time.zone.today - published_at.in_time_zone.to_date`(정수 일수). `Time.zone`은 Asia/Tokyo(기존 설정).
- 라벨은 "에버그린 후보" — "에버그린"으로 단정하지 않는다(대리지표). 검증 승격(FR-14)의 값은 **계산하지 않는다** — `VideoDailyStat` 스키마가 미래 소재지로 자리만 유지(MVP Out of Scope, 신규 컬럼·계산 없음).
- 물질화: `VideoScore`에 `evergreen_candidate` boolean 추가(3.2 패턴, null:false default false). 판정은 채널의 VideoScore 각각에 대해 후보 여부를 계산해 `evergreen_candidate` 갱신(idempotent). 3.2 `CalculatePerformance.update!`가 이 컬럼을 건드리지 않으므로(3개 컬럼만) 스테이지 간 보존.
- 잡 체인 append(AD-11): `DailyCollectionJob`이 `Snapshot::RecordDailyStats` **뒤에** 채널별로 `CalculateBaseline`→`CalculatePerformance`→`DetermineEvergreen`을 순서대로 호출(각 스테이지가 이전 산출을 DB에서 읽음). 잡은 조립만, 로직은 서비스. 채널별 rescue로 한 채널 스코어링 실패가 런·다른 채널을 버리지 않음(기존 수집 패턴 정합).
- nil 방어(AD-9): `published_at` nil이면 나이 미상 → 후보 아님(false). `performance_multiple` nil이면 후보 아님. 예외 없음.

**Block If:**
- (없음 — 순수 로직·기존 스키마 확장·API 무관.)

**Never:**
- 배수 > 1만으로 후보 판정(두 임계 AND 필수). 스냅샷 이력으로 검증 승격 값 계산(MVP Out of Scope). "에버그린" 단정 라벨.
- 성과 배수·기준선 재계산 로직을 이 서비스에 복제(3.1/3.2 산출 읽기). 잡에 판정 로직 복제(AD-11 위임).
- 웹 요청 경로 계산. 화면·컨트롤러(Epic 6). 스냅샷 앞에 스코어링 배치.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 후보 | age 200일, 배수 3 (min 180·2) | evergreen_candidate=true | — |
| 나이만 | age 200일, 배수 1.5 | false(배수 미달) | — |
| 배수만 | age 100일, 배수 5 | false(나이 미달) | — |
| 배수>1 아님 | age 200일, 배수 1.5 | false(1.5는 min_multiple 2 미만) | — |
| 나이 경계 | age 정확히 180일, 배수 2 | true(포함 하한 >=) | — |
| published nil | published_at nil | false(나이 미상) | AD-9 방어 |
| 배수 nil | performance_multiple nil | false | AD-9 방어 |
| Tokyo 경계 | UTC 늦은 밤 vs Tokyo 날짜 | Tokyo 날짜로 경과일 | — |
| 재계산 | 이미 flag 있음 | 같은 행 갱신(보존·중복 없음) | — |
| 체인 순서 | 잡 실행 | 스냅샷 뒤 baseline→performance→evergreen 순 | 채널별 rescue |
| 스테이지 보존 | performance 재실행 | evergreen_candidate 값 유지(3컬럼만 갱신) | — |

</intent-contract>

## Code Map

- `db/migrate/*_add_evergreen_candidate_to_video_scores.rb` -- `video_scores.evergreen_candidate` boolean null:false default false
- `app/services/scoring/determine_evergreen.rb` -- `Scoring::DetermineEvergreen.new(channel).call` — 나이 AND 배수 판정·물질화
- `app/jobs/daily_collection_job.rb` -- 스냅샷 뒤 스코어링 3스테이지 append(채널별 rescue, 조립만)
- `app/services/scoring/calculate_baseline.rb`·`calculate_performance.rb` -- 이전 스테이지(3.1/3.2, 재사용)
- `app/models/video_score.rb` -- `evergreen_candidate` 컬럼(모델은 자동 반영, 변경 최소)
- `config/scoring.yml` -- `evergreen.min_age_days`·`min_multiple`(기존)
- `test/services/scoring/determine_evergreen_test.rb` -- 판정 매트릭스
- `test/jobs/daily_collection_job_test.rb` -- 체인 append 순서·스코어링 물질화(기존에 추가)

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_evergreen_candidate_to_video_scores.rb` -- `add_column :video_scores, :evergreen_candidate, :boolean, null: false, default: false` -- 후보 물질화 자리 -- `db:migrate && db:prepare`
- [x] `app/services/scoring/determine_evergreen.rb` -- `Scoring::DetermineEvergreen.new(channel).call`: `min_age = Config.fetch(:evergreen,:min_age_days)`, `min_multiple = Config.fetch(:evergreen,:min_multiple)`, `today = Time.zone.today`. 채널의 VideoScore(joins video, channel 스코프) 각각에 대해: `published_at` nil이거나 `performance_multiple` nil이면 candidate=false; 아니면 `age = (today - video.published_at.in_time_zone.to_date).to_i`, `candidate = age >= min_age && performance_multiple >= min_multiple`. `score.update!(evergreen_candidate: candidate)`. 전체 트랜잭션 -- 판정·물질화 AC
- [x] `app/jobs/daily_collection_job.rb` -- `Snapshot::RecordDailyStats.call` 뒤 자리 주석을 실제 append로 교체: `Channel.not_excluded.find_each do |channel| CalculateBaseline→CalculatePerformance→DetermineEvergreen; rescue => e (로그·계속) end`. 조립만, 순서 baseline→performance→evergreen -- 체인 append AC
- [x] `test/services/scoring/determine_evergreen_test.rb`·`test/jobs/daily_collection_job_test.rb` -- I/O 매트릭스(나이 AND 배수·한쪽만 false·배수>1 아님·경계 180·published nil·Tokyo 경계·재계산 보존) + 잡 체인 스코어링 물질화·순서 -- 검증

**Acceptance Criteria:**
- Given 기준선·성과 배수가 계산된 영상, when 에버그린 후보를 판정하면, then 나이(경과일 ≥ `min_age_days`)와 성과 배수(≥ `min_multiple`) 두 임계를 **동시 충족**해야 하며 배수>1을 후보 기준으로 쓰지 않는다.
- Given 판정된 영상, when 라벨링하면, then "에버그린 후보"로 표시되고 "에버그린"으로 단정하지 않는다.
- Given 후보 판정, when 계산하면, then 스냅샷 없이 현재 조회수·업로드일·기준선(=성과 배수)만으로 계산된다(1일차 동작).
- Given 검증 승격(FR-14), when MVP를 보면, then 값은 계산하지 않고 `VideoDailyStat` 스키마가 미래 소재지로 자리만 유지한다.
- Given Epic 3 스코어링 스테이지, when `DailyCollectionJob`이 실행되면, then 스냅샷 저장 뒤에 기준선→성과 배수→에버그린 후보 순서로 append되고 각 스테이지가 이전 산출을 DB에서 읽는다.
- Given `published_at`이 nil이거나 `performance_multiple`이 nil, when 판정하면, then 예외 없이 후보 아님(false)으로 처리된다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3: (high 0, medium 2, low 1)
- defer: 0
- reject: 7: (low 7)
- addressed_findings:
  - `[medium]` `[patch]` `daily_collection_job.rb` 스코어링 per-channel rescue가 로그만 하고 전 채널 실패해도 fetch 카운터 기반 `finalize`가 succeed! 위장 — 2.5 수집 정직성 불변식 위반. `scoring_attempted/scoring_failed` 추적 → 전 채널 스코어링 실패 시 `run.fail!`(finalize 와 동일 raise 없이 failed 기록) + 정직성 테스트.
  - `[medium]` `[patch]` `daily_collection_job.rb` 세 스테이지가 각 별 트랜잭션이라 중간 실패 시 '새 배수 + 옛 에버그린' 불일치 잔존. 채널별 `ApplicationRecord.transaction`으로 세 스테이지 원자화(all-or-nothing — 실패 시 채널은 어제의 정합 상태 유지).
  - `[low]` `[patch]` `daily_collection_job.rb` 스코어링이 `not_excluded`(전체)라 youtube_channel_id 없는 handle-only 채널에 빈 기준선을 매일 생성. 수집 스코프(`where.not(youtube_channel_id: nil)`)로 정렬 + 스코프 테스트.
- rejected(noise): retry_on Deadlocked 가 스코어링에 무효(기존 fetch 루프와 동일 의도적 per-channel rescue — 스코어링 idempotent·다음 런 재계산), needs_verification+evergreen 공존(3.2 선례 독립 축·스펙 AC는 age AND multiple만·표시 화해 Epic 6), fail 예정 런도 스코어링 실행(idempotent 무해), `.each` 메모리(채널 스코프 bounded·MVP), today 채널별 재계산(4am 런 자정 미교차·정확 180일 경계 flip 무시 가능), Config.fetch nil→ArgumentError(fetch 는 missing 시 KeyError·값 존재), 단일 update! 롤백(boolean 갱신 실패 불가·채널 트랜잭션으로 원자성 확보).

## Design Notes

**에버그린은 성과 배수 스테이지 산출을 읽는다.** 성과 배수 = view ÷ 기준선(3.2)이므로 "현재 조회수·기준선만으로"는 `VideoScore.performance_multiple`를 읽는 것으로 충족된다 — 별도 재계산 없음(AD-11 스테이지가 이전 산출을 DB에서 읽는 규약). 후보는 `age >= min_age_days AND multiple >= min_multiple` 두 임계 AND. 배수>1을 기준으로 쓰지 않는 이유: 평소보다 조금이라도 나은 오래된 영상이 전부 후보가 되면 신호가 죽는다 — 의미 있는 배수(≥2)와 충분한 나이(≥180일) 동시 충족만 검색 유입형 후보로 본다.

**나이는 Tokyo 날짜 경계.** `Time.zone`은 Asia/Tokyo(기존). `published_at`(UTC datetime)을 `in_time_zone.to_date`로 Tokyo 발행일로 환산하고 `Time.zone.today`와의 일수 차로 경과일을 낸다 — 스냅샷 date 경계(2.x)와 동일 규약. published_at nil이면 나이 미상이라 후보 아님(AD-9).

**대리지표·1일차·검증 자리.** 스냅샷 이력 없이 첫날부터 동작하는 대리지표라 "에버그린"이 아니라 "후보"다(FR-5 증폭 편향 상속). 검증 승격(FR-14, 시간에 걸친 유지 확인)은 MVP Out of Scope — `VideoDailyStat`(2.x)이 미래 소재지로 이미 존재하므로 신규 스키마·계산 없이 자리만 유지한다.

**체인 append(AD-11).** 잡은 스냅샷 뒤 채널별로 세 스테이지를 순서 호출만 한다(로직은 서비스). 채널별 sequential이라 baseline(A) 커밋 → performance(A)가 baseline(A) 읽음 → evergreen(A)가 performance(A) 읽음 — "이전 산출을 DB에서 읽음"을 채널 스코프로 만족. 채널별 rescue로 한 채널 스코어링 실패를 격리(기존 수집 rescue 패턴). 스코어링은 파생·idempotent라 다음 런이 재계산.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: evergreen_candidate 컬럼 추가
- `bin/rails test test/services/scoring/determine_evergreen_test.rb test/jobs/daily_collection_job_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "DailyCollectionJob.perform_now; p VideoScore.where(evergreen_candidate: true).count; p JobRun.last.status"` -- expected: 스코어링 물질화·succeeded

## Auto Run Result

Status: done

**구현 요약** — `Scoring::DetermineEvergreen.new(channel).call`이 나이(Tokyo 경과일 ≥ `min_age_days`) AND 성과 배수(`VideoScore.performance_multiple` ≥ `min_multiple`) 두 임계 동시 충족을 스냅샷 없이 판정해 `VideoScore.evergreen_candidate`로 물질화("에버그린 후보" 라벨, 단정 아님). published_at·배수 nil 방어. 그리고 `DailyCollectionJob`이 스냅샷 뒤 채널별로 기준선→성과배수→에버그린 3스테이지를 한 트랜잭션·순서로 append(AD-11, 조립만). 검증 승격(FR-14)은 계산 안 함(VideoDailyStat 자리만 유지).

**변경/신규 파일**
- `db/migrate/20260724100010_add_evergreen_candidate_to_video_scores.rb` — evergreen_candidate boolean
- `app/services/scoring/determine_evergreen.rb`(신규) — 나이 AND 배수 판정·물질화
- `app/jobs/daily_collection_job.rb` — 스냅샷 뒤 스코어링 3스테이지 append(채널별 트랜잭션·rescue·전 채널 실패 정직성)
- `test/services/scoring/determine_evergreen_test.rb`(신규 12)·`test/jobs/daily_collection_job_test.rb`(추가)
- `db/schema.rb` — 마이그레이션 반영

**리뷰 결과** — Blind + Edge Case 병렬. patch 3(전 채널 스코어링 실패 정직성 fail!·채널별 3스테이지 원자 트랜잭션·스코어링 스코프를 수집과 정렬), defer 0, reject 7(retry_on·needs_verification 공존·.each·today 재계산·Config nil·단일 update! 등 — 기존 패턴 정합이거나 불가능/무해). intent_gap·bad_spec 0. 통합 스토리·잡 조립 경계 구조 변경이라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 19 runs/51 assertions, 전체 223 runs/821 assertions, 0 failures(회귀 없음). 나이 AND 배수·한쪽만 false·배수>1 아님·경계 180·published nil·배수 nil·Tokyo 경계·재계산 보존·스테이지 보존·체인 append 순서·전 채널 스코어링 실패 정직성·handle-only 스코프 제외 검증. `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — needs_verification+evergreen 공존 화해는 Epic 6 표시. 검증 승격은 MVP Out of Scope. 튜닝값 잠정(본개발 실측 확정). Epic 3 스코어링 엔진 완결 — 다음은 Epic 4(임베딩·유사영상·콘텐츠 갭).
