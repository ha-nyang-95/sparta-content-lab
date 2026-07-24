---
title: 'Story 5.2: 추천 주제 3개 산출 + 정직성 + 결정적 동점 + 체인 최종 append'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-5-1-opportunity-score.md'
warnings: []
baseline_revision: '2bba922e1884fea9a3980278b0a342e5b46961d2'
final_revision: '851b55782f9b1674ab8ea79959f6f95faf3fcdff'
---

<intent-contract>

## Intent

**Problem:** MVP 최종 산출물 — 다음 주 제작할 주제 3개를 근거와 함께 줘야 한다. 기회 점수(5.1)로 랭킹된 주제 클러스터에서 상위 3개를 정직성·결정적 동점으로 뽑아 스냅샷 저장하고, 일일 체인을 완성해야 한다.

**Approach:** `Scoring::GenerateRecommendations`(app/services/scoring 경계)가 기회 점수 상위 주제 클러스터를 결정적 정렬(기회 점수 → 성과 배수 → 최신성 → 클러스터 id)로 최대 `max_count`(config, 3)개 뽑아, 각각 `Recommendation(reference_video_ids, topic_label, opportunity_score)`로 **생성 시점 스냅샷** 저장한다(휘발 `TopicCluster`에 FK 금지, AD-10). 자격 주제(기회 점수 > 0)가 3개 미만이면 억지로 만들지 않는다(정직성 AD-16). 그리고 Epic 5 스테이지(기회 점수 → 추천)를 `DailyCollectionJob` 체인의 주제 클러스터 뒤에 append해 일일 체인을 완성한다(AD-11). 순수 계산·API 무관.

## Boundaries & Constraints

**Always:**
- 로직은 `app/services/scoring` 경계에(AD-2). `max_count`는 `Scoring::Config`로 `config/scoring.yml`의 `recommendation.max_count`에서만 읽는다(AD-4, 하드코딩 금지).
- `Recommendation`은 **생성 시점 스냅샷** — `reference_video_ids`(경쟁 참고 영상 id 배열, JSON 직렬화)·`topic_label`·`opportunity_score`를 자체 저장하고 **휘발 `TopicCluster`에 FK하지 않는다**(AD-10, 재라벨링·재구축에도 댕글링 없음).
- 상위 선정 = **결정적 정렬**: `opportunity_score` 내림차순 → 동점 시 클러스터 성과 배수(경쟁 최대 performance_multiple) 내림차순 → 최신성(경쟁 최근 발행) 내림차순 → 클러스터 id 오름차순(완전 결정적, FR-19). 최대 `max_count`개.
- **정직성(AD-16)**: 자격 주제(기회 점수 > 0 — 경쟁 신호 있는 클러스터)만 추천한다. 자격이 `max_count` 미만이면 그 수만 생성(억지로 3개 만들지 않음). 자격 0이면 추천 0개.
- 배치 재생성 — 매 실행 `Recommendation.delete_all` 후 현재 상위로 재구축(스냅샷이라 자체 완결·FK 없음). **배치**(웹 요청 경로 아님, AD-3). 결정적.
- 잡 체인 최종 append(AD-11): `DailyCollectionJob`이 주제 클러스터(4.4) 뒤에 `Scoring::CalculateOpportunityScore`(5.1) → `Scoring::GenerateRecommendations`(이 스토리)를 순서대로 호출. 잡은 조립만(스테이지별 rescue).

**Block If:**
- (없음 — 순수 로직·기존 산출 소비·API 무관.)

**Never:**
- `Recommendation`이 `TopicCluster`에 FK(AD-10 위반). 자격 미달인데 억지로 3개 채우기(정직성 위반). max_count 하드코딩.
- 추천 이유·카드 문구 생성(Epic 6 표시가 스냅샷 데이터로 렌더). 비결정적 동점 정렬. 웹 요청 경로 계산. 화면.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 상위 3 | 자격 클러스터 5개 | 기회 점수 상위 3개 Recommendation | — |
| 3개 미만 정직 | 자격 클러스터 2개 | 2개만 생성(억지 3개 아님) | — |
| 자격 0 | 기회 점수 >0 클러스터 없음 | Recommendation 0개 | — |
| 동점 성과 | 기회 점수 동, 성과 배수 다름 | 성과 배수 높은 것 먼저 | — |
| 동점 최신성 | 기회·성과 동, 최신성 다름 | 최근 것 먼저 | — |
| 완전 결정 | 모두 동점 | 클러스터 id 오름차순 | — |
| 스냅샷 | 클러스터 재구축돼도 | reference_video_ids·label 자체 보존(FK 없음) | — |
| 직렬화 | reference_video_ids | JSON 배열 저장·복원 | — |
| 재생성 | 재실행 | delete_all 후 현재 상위 재구축 | — |
| 체인 append | 잡 실행 | 클러스터 뒤 기회 점수 → 추천 순 | 스테이지별 rescue |

</intent-contract>

## Code Map

- `db/migrate/*_create_recommendations.rb` -- `recommendations`(reference_video_ids text/json, topic_label string, opportunity_score float, rank)
- `app/models/recommendation.rb` -- `Recommendation`(reference_video_ids JSON 직렬화, TopicCluster FK 없음)
- `app/services/scoring/generate_recommendations.rb` -- `Scoring::GenerateRecommendations.call` 결정적 선정·스냅샷 저장
- `app/models/topic_cluster.rb`·`video_score.rb`·`video.rb` -- 소스(기존)
- `app/jobs/daily_collection_job.rb` -- 클러스터 뒤 기회 점수 → 추천 스테이지 append(조립만)
- `config/scoring.yml` -- `recommendation.max_count`(기존에 추가)
- `test/services/scoring/generate_recommendations_test.rb`·`test/models/recommendation_test.rb`·`test/jobs/daily_collection_job_test.rb` -- 상위·정직성·동점·스냅샷·직렬화·체인

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_create_recommendations.rb` -- `create_table :recommendations`: `reference_video_ids`(text), `topic_label`(string), `opportunity_score`(float), `rank`(integer), timestamps. **TopicCluster FK 없음**(스냅샷) -- 스냅샷 물질화 -- `db:migrate && db:prepare`
- [x] `app/models/recommendation.rb` -- `Recommendation < ApplicationRecord`; `serialize :reference_video_ids, coder: JSON, type: Array`(또는 json 컬럼) -- 스냅샷 모델 -- 모델
- [x] `app/services/scoring/generate_recommendations.rb` -- `Scoring::GenerateRecommendations.new.call`: `max = Config.fetch(:recommendation,:max_count)`; 자격 클러스터(`TopicCluster.where("opportunity_score > 0")`) 각각 tie 값(경쟁 최대 performance_multiple·경쟁 최소 경과일) 계산 → `sort_by [-opportunity_score, -tie_perf, tie_min_age, id]` → `first(max)`; 트랜잭션 내 `Recommendation.delete_all` 후 각 클러스터로 `Recommendation.create!(topic_label: 대표 경쟁 영상 제목, opportunity_score:, reference_video_ids: 경쟁 영상 id 배열, rank:)` -- 선정·스냅샷 AC
- [x] `app/jobs/daily_collection_job.rb` -- `run_similarity_stages`(4.4)의 스테이지 해시에 `"기회 점수" => CalculateOpportunityScore`, `"추천" => GenerateRecommendations` 를 클러스터 뒤에 순서 추가(스테이지별 rescue). 조립만 -- 체인 append AC
- [x] `test/services/scoring/generate_recommendations_test.rb`·`test/models/recommendation_test.rb`·`test/jobs/daily_collection_job_test.rb` -- I/O 매트릭스(상위·정직성·동점 3단·스냅샷·직렬화·체인 append) -- 검증

**Acceptance Criteria:**
- Given 기회 점수가 산출된 주제 클러스터, when 추천 3개를 생성하면, then `Recommendation(reference_video_ids, topic_label, opportunity_score)`이 생성 시점 스냅샷으로 저장된다(휘발 `TopicCluster`에 FK 금지).
- Given 자격 주제가 `max_count` 미만, when 생성하면, then 억지로 채우지 않고 자격 수만 생성한다(정직성, "N개 확보"는 Epic 6 표시).
- Given 동점, when 정렬하면, then 결정적이다 — 기회 점수 → 성과 배수 → 최신성 → 클러스터 id 순.
- Given Epic 5 스테이지, when `DailyCollectionJob`이 실행되면, then 주제 클러스터 뒤에 기회 점수 → 추천 순서로 append되어 일일 체인이 완성된다.
- Given 각 추천, when 소비하면, then 참고 경쟁 영상(reference_video_ids)·주제명(topic_label)·기회 점수를 담는다(추천 이유·카드 렌더는 Epic 6).

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 2: (high 0, medium 1, low 1)
- defer: 0
- reject: 5: (low 5)
- addressed_findings:
  - `[medium]` `[patch]` `generate_recommendations.rb` 4.4가 클러스터를 매 배치 재구축(opportunity_score NULL 기본)하는데 상류 기회 점수 스테이지가 실패(per-stage rescue 삼킴)하면 자격 0으로 delete_all → 어제의 유효 추천 파괴. `TopicCluster.exists? && where.not(opportunity_score: nil).none?`면 재구축 skip(스테일 방지). 정직한 자격 0(점수 계산됐으나 >0 없음)과 구분 + 두 테스트.
  - `[low]` `[patch]` `generate_recommendations.rb` `topic_label` 최고 경쟁 영상 title nil 시 `cluster.videos.first`(자사 포함)로 폴백 → 자사 영상 제목이 주제명 될 수 있음. 폴백을 경쟁 멤버 내로 한정(`members.filter_map(&:title).first`) + 테스트.
- rejected(noise): max_count 0/음수(큐레이션 config·기본 3·operator 오설정), index_by 다중 VideoScore(video_id 유니크·1개 보장), channel nil NPE(채널 삭제 경로 없음·belongs_to 필수·5.1과 동일 기존), 마이그레이션 무제약(서비스가 항상 rank·점수·라벨 설정·스냅샷 테이블), no-history delete_all(AD-10 스냅샷 설계·이력 누적 아님).

## Design Notes

**스냅샷 = FK 없는 자체 완결(AD-10).** `TopicCluster`는 휘발(4.4 재구축)이라 `Recommendation`이 FK하면 매 배치 댕글링된다. 그래서 생성 시점의 `reference_video_ids`(경쟁 영상 id 배열)·`topic_label`·`opportunity_score`를 자체 저장한다 — 클러스터가 재라벨링·재구축돼도 추천은 유효하다. `reference_video_ids`는 JSON 직렬화(SQLite text). 매 배치 delete_all 후 현재 상위로 재구축(현재 주 추천).

**결정적 동점(FR-19).** 정렬키 = `[opportunity_score DESC, tie_perf DESC, tie_recency DESC, cluster.id ASC]`. tie_perf = 클러스터의 경쟁 멤버 `performance_multiple` 최대(5.1 성과 스코프와 동일), tie_recency = 경쟁 멤버 최근 발행(경과일 최소). 클러스터 id로 완전 결정화(모두 동점이어도 안정). 픽스처로 3단 동점 검증.

**정직성(AD-16).** 자격 = `opportunity_score > 0`(경쟁 신호 있는 주제 — 자사 전용/빈 클러스터는 5.1에서 0이라 제외). 자격이 max_count 미만이면 그 수만 생성(억지 금지). 콜드스타트·빈약한 주엔 추천이 3개 미만일 수 있고, "이번 주 N개 확보" 문구는 Epic 6이 개수로 렌더한다.

**topic_label(잠정).** 클러스터 대표 = 경쟁 멤버 중 성과 배수 최고 영상의 제목을 topic_label로 스냅샷한다(주제명 생성 방식은 FR-19 미명세 — LLM 라벨링은 범위 밖, 대표 제목이 잠정). 추천 이유·참고 영상 상세는 Epic 6이 reference_video_ids로 렌더한다.

**체인 최종 append(AD-11).** 4.4가 만든 전역 스테이지 러너에 기회 점수(5.1)·추천(5.2)을 클러스터 뒤로 추가한다 — 일일 체인이 수집→스냅샷→스코어링(Epic3)→유사도(Epic4)→기회 점수→추천(Epic5)으로 완성된다. 스테이지별 rescue(파생·idempotent·다음 런 재계산).

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: recommendations 테이블
- `bin/rails test test/services/scoring/generate_recommendations_test.rb test/models/recommendation_test.rb test/jobs/daily_collection_job_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "DailyCollectionJob.perform_now; p [Recommendation.count, JobRun.last.status]"` -- expected: 추천·succeeded

## Auto Run Result

Status: done

**구현 요약** — `Scoring::GenerateRecommendations`가 자격 주제 클러스터(opportunity_score > 0)를 결정적 정렬(기회 점수 → 경쟁 성과 배수 → 최신성 → 클러스터 id)로 최대 `recommendation.max_count`(config 3)개 뽑아 `Recommendation(reference_video_ids JSON·topic_label·opportunity_score·rank)` **스냅샷**으로 물질화한다(휘발 TopicCluster에 FK 금지, AD-10). 자격 미달이면 그 수만(정직성 AD-16). topic_label은 대표 경쟁 영상 제목(경쟁 내 폴백). 상류 실패(점수 전량 NULL) 시 기존 추천 보존(스테일 방지). `DailyCollectionJob` 체인의 클러스터 뒤에 기회 점수(5.1)→추천 스테이지를 append해 일일 체인 완성. 순수 계산·API 무관.

**변경/신규 파일**
- `db/migrate/20260724100018_create_recommendations.rb`·`app/models/recommendation.rb`(신규, JSON 직렬화)
- `app/services/scoring/generate_recommendations.rb`(신규)·`config/scoring.yml`(recommendation.max_count)
- `app/jobs/daily_collection_job.rb`(run_similarity_stages에 기회 점수·추천 append)
- `test/services/scoring/generate_recommendations_test.rb`·`test/models/recommendation_test.rb`(신규)·`test/jobs/daily_collection_job_test.rb`(추가)·`db/schema.rb`

**리뷰 결과** — Blind + Edge Case 병렬. patch 2(상류 실패 시 추천 보존 가드·topic_label 경쟁 내 폴백), defer 0, reject 5(max_count 0·index_by·channel nil·마이그레이션·no-history — 큐레이션/보장/삭제경로 없음/설계). intent_gap·bad_spec 0. capstone 마무리+체인 seam 로버스트니스라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 13→ 전체 329 runs/1033 assertions, 0 failures(회귀 없음). 상위 N·정직성 <max_count·자격 0·동점 3단(성과·최신성·id)·스냅샷 FK 없음·직렬화·topic_label 경쟁 폴백·상류 실패 보존·idempotent·체인 append 검증. `proposal.html`·`config/scoring.yml`(별도) 정합.

**완결** — 핵심 파이프라인(Epic 1~5) 완결. 일일 체인 = 수집→스냅샷→스코어링(Epic3)→유사도(Epic4)→기회 점수→추천 3개(Epic5). Recommendation은 휘발 클러스터 무관 스냅샷. 실 YouTube·Gemini 호출은 보류(키 대기). 남은 것은 Epic 6(대시보드 6화면)·Epic 7(인증) — 표시/UI 계층.
