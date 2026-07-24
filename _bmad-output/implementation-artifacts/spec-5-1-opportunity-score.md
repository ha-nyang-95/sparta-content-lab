---
title: 'Story 5.1: 기회 점수 산출 (4입력 정규화 가중합)'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
warnings: []
baseline_revision: '904cc3595cb7b101c5ceb13816cd2a583421491f'
final_revision: 'a1ae63f565d0ef59b5b25dac8e8277a300954029'
---

<intent-contract>

## Intent

**Problem:** 추천 주제를 우선순위로 랭킹하려면 단일 지표(성과 배수)가 아니라 여러 신호를 합친 종합 점수가 필요하다. 4입력을 정규화·가중합한 기회 점수(0~100)가 없다.

**Approach:** `Scoring::CalculateOpportunityScore`(app/services/scoring 경계)가 각 `TopicCluster`(4.4)에 대해 4입력(성과 배수 신호·경쟁 공통성·콘텐츠 갭·최신성)을 멤버 영상에서 집계해 각각 [0,1]로 정규화하고, `scoring.yml`의 가중치로 가중합한 뒤 ×100해 `TopicCluster.opportunity_score`로 배치 물질화한다. **정규화 구조는 FR-21로 고정, 파라미터·가중치는 config 튜닝값**(AD-4). 성과 배수 하나로 대체되지 않는 별도 종합 지표. 순수 계산·API 무관.

## Boundaries & Constraints

**Always:**
- 점수 로직은 `app/services/scoring` 경계에(AD-2). 가중치·정규화 파라미터는 `Scoring::Config`로 `config/scoring.yml`의 `opportunity_score.weights`·`opportunity_score.normalization`에서만 읽는다(AD-4, 하드코딩 금지).
- 기회 점수 = **4입력 각각 [0,1] 정규화 → 가중합 → ×100**(FR-21 구조 불변). 4입력 모두 사용 — 성과 배수 하나로 대체 금지(별도 종합 지표). 정규화 매핑(FR-21): 성과 배수 → `min(배수/performance_divisor, 1)`, 콘텐츠 갭(4범주) → 버킷별 `content_gap_values`([0,1]), 최신성 → 선형 감쇠(`max(0, 1 - 경과일/recency_full_decay_days)`), 경쟁 공통성 → `min(경쟁채널수/commonality_cap, 1)`.
- 단위 = **주제 클러스터**(TopicCluster). 5.2 추천이 소비. `TopicCluster.opportunity_score`(float) 물질화. **배치**(웹 요청 경로 재계산 없음, AD-3). 결정적(클러스터 id 순).
- 4입력 집계(멤버 영상에서, 잠정·문서화): 성과 배수 신호 = 멤버의 `VideoScore.performance_multiple` **최대**(nil 스킵), 경쟁 공통성 = 멤버 중 **경쟁(is_own:false) 채널 수(distinct)**, 콘텐츠 갭 = 멤버 경쟁 영상의 `content_gap_bucket` → [0,1] 평균, 최신성 = 멤버 중 **가장 최근** `published_at`의 Tokyo 경과일 감쇠.
- nil 방어(AD-9): 값 없는 입력은 정규화 0(예: perf 없으면 0, published_at 없으면 최신성 0). 예외 없음.

**Block If:**
- (없음 — FR-21이 정규화 구조 정의, 값은 config 튜닝. 순수 로직·기존 산출 소비.)

**Never:**
- 성과 배수만으로 기회 점수 대체(4입력 구조 불변). 정규화 파라미터·가중치 하드코딩. 영상 단위 점수(주제 클러스터 단위).
- 잡 체인 append(5.2 담당). 추천 생성·Recommendation(5.2). 웹 요청 경로 계산. 화면(Epic 6).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 정상 점수 | 4입력 모두 있음 | 정규화·가중합·×100, 0~100 | — |
| 성과 정규화 | 최대 배수 5, divisor 10 | perf_norm = 0.5 | — |
| 성과 상한 | 최대 배수 20, divisor 10 | perf_norm = 1.0(min) | — |
| 갭 매핑 | 경쟁 영상 not_made | gap_norm = content_gap_values[not_made] | — |
| 최신성 감쇠 | 경과일 45, decay 90 | recency = 0.5 | — |
| 최신성 하한 | 경과일 > decay | recency = 0.0(max 0) | — |
| 공통성 상한 | 경쟁 채널 10, cap 5 | commonality = 1.0(min) | — |
| 구조 불변 | 성과 높고 나머지 0 | 점수 < 성과 단독(가중 0.25만 반영) | — |
| nil 방어 | perf 없음·published nil | 해당 입력 0, 예외 없음 | AD-9 |
| 물질화 | 클러스터들 | opportunity_score 저장(0~100) | — |
| 재계산 | 재실행 | 현재 멤버로 갱신 | — |

</intent-contract>

## Code Map

- `db/migrate/*_add_opportunity_score_to_topic_clusters.rb` -- `topic_clusters.opportunity_score` float
- `app/services/scoring/calculate_opportunity_score.rb` -- `Scoring::CalculateOpportunityScore.call` 집계·정규화·가중합·물질화
- `app/models/topic_cluster.rb` -- 멤버 소비(has_many videos, 기존)
- `app/models/video_score.rb`·`app/models/channel.rb` -- 입력 소스(기존)
- `config/scoring.yml` -- `opportunity_score.weights`·`normalization`(기존에 채움)
- `test/services/scoring/calculate_opportunity_score_test.rb` -- 4입력 정규화·가중합·경계·nil·구조 불변·config 읽기

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_opportunity_score_to_topic_clusters.rb` -- `add_column :topic_clusters, :opportunity_score, :float` -- 점수 물질화 -- `db:migrate && db:prepare`
- [x] `app/services/scoring/calculate_opportunity_score.rb` -- `Scoring::CalculateOpportunityScore.new.call`: weights·normalization 로드; 각 `TopicCluster.order(:id)`에 대해 4입력 집계·정규화(성과=멤버 VideoScore.performance_multiple 최대 → `min(x/divisor,1)`; 공통성=멤버 경쟁 채널 distinct 수 → `min(n/cap,1)`; 갭=멤버 경쟁 VideoScore.content_gap_bucket → content_gap_values 평균; 최신성=멤버 최근 published_at Tokyo 경과일 → `[0, 1-days/decay].max`); `score = (Σ w_i·norm_i)*100`; `cluster.update!(opportunity_score: score)`. 트랜잭션. nil 입력은 0 -- 점수 산출 AC
- [x] `test/services/scoring/calculate_opportunity_score_test.rb` -- I/O 매트릭스(각 정규화 매핑·가중합·경계·nil 방어·구조 불변·config 파라미터 읽기) -- 검증

**Acceptance Criteria:**
- Given 성과 배수·콘텐츠 갭·주제 클러스터가 물질화된 상태, when 기회 점수를 산출하면, then 4입력이 각각 [0,1]로 정규화되고 가중합 후 ×100 된다.
- Given 정규화 매핑과 가중치, when 읽으면, then `scoring.yml`의 `opportunity_score.normalization`·`weights`에서 읽고(구조 불변, 값만 설정) 하드코딩하지 않는다.
- Given 기회 점수, when 성과 배수와 비교하면, then 4입력 종합 지표라 성과 배수 하나로 대체되지 않는다(성과 높고 나머지 낮으면 점수가 성과 단독보다 낮다).
- Given 산출, when 실행하면, then `TopicCluster.opportunity_score`로 배치 물질화된다(웹 요청 경로 재계산 없음).
- Given 입력 값이 nil(성과 없음·published_at 없음), when 정규화하면, then 그 입력은 0으로 처리되고 예외가 없다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3: (high 1, medium 2, low 0)
- defer: 0
- reject: 6: (low 6)
- addressed_findings:
  - `[high]` `[patch]` `calculate_opportunity_score.rb` `recency_norm`이 하한만 clamp — 미래 published_at(예약 발행·타임존)로 min_age 음수 → recency>1 → 점수 100 초과. `(1 - age/decay).clamp(0.0, 1.0)`로 상한 추가 + 미래 발행 테스트.
  - `[medium]` `[patch]` 0~100 계약이 emergent(가중치 합·정규화 가정) — `score.clamp(0.0, 100.0)`로 구조 보장.
  - `[medium]` `[patch]` own-only 클러스터가 perf+recency(전 멤버 집계)로 최대 50점 — 기회 점수의 목적('다음 주 제작할 주제')상 자사 기존 영상은 기회 아님. perf·recency를 경쟁(is_own:false) 스코프로 정렬 → 기회 = 경쟁 신호, 자사 전용 클러스터는 0점. 구조-불변 테스트를 경쟁 클러스터로·own-only 0점 테스트 추가.
- rejected(noise): nil channel NPE(Video belongs_to :channel 필수·nil 불가능), commonality_cap/decay 0 나눗셈(큐레이션 config·타 divisor도 무가드), 서브해시 Hash#[] 가 Config.fetch KeyError 우회(구조 고정·기본값 존재), score 미반올림(표시가 반올림·5.2 정렬 float 무관), no-data vs worst 동일 0(AD-9 명시 nil 방어 결정·문서화), 클러스터별 VideoScore N+1(MVP 규모·클러스터 bounded).

## Design Notes

**주제 클러스터 단위·구조 고정.** 기회 점수는 추천 단위(주제)라 `TopicCluster`에 물질화한다(5.2가 소비). FR-21이 4입력 [0,1] 정규화 → 가중합 → ×100 **구조를 고정**하고, 정규화 파라미터·가중치는 `[ASSUMPTION: 본개발 실측 확정]`이라 `scoring.yml`의 튜닝값이다(AD-4). 4입력 모두 반영해 성과 배수 단독 대체를 구조적으로 배제한다(투명 가중합).

**정규화(FR-21).** 성과 배수 → `min(배수/performance_divisor, 1)`(무한대 상한), 콘텐츠 갭 → 버킷별 `content_gap_values`(미제작=1 최대 기회…포화=0), 최신성 → 선형 감쇠 `max(0, 1 - 경과일/recency_full_decay_days)`, 경쟁 공통성 → `min(경쟁채널수/commonality_cap, 1)`. 모든 파라미터 config.

**클러스터 집계(경쟁 스코프·잠정).** 기회 점수는 '다음 주 **제작할** 주제' 랭킹이라 4입력 모두 **경쟁(is_own:false) 멤버 신호**로 집계한다 — 자사 기존 영상은 기회가 아니므로. 성과 신호=경쟁 멤버 성과 배수 **최대**(주제의 경쟁 최고 성과), 경쟁 공통성=**경쟁 채널 distinct 수**, 콘텐츠 갭=경쟁 영상 버킷값 **평균**(버킷은 자사 커버리지를 반영), 최신성=경쟁 멤버 **최근** 발행 경과일. 따라서 **자사 전용 클러스터(경쟁 멤버 0)는 기회 점수 0**(이미 만든 주제는 기회 아님). 집계 방식은 FR-21 미명세라 잠정(본개발 실측 확정) — Tokyo 경과일 규약은 3.4와 동일. nil·경쟁 없음 입력은 정규화 0(AD-9). 정규화·가중합 결과는 `[0,100]`으로 clamp(미래 발행·가중치 튜닝에도 범위 보장).

**범위.** 5.1은 점수 산출·물질화까지. 잡 체인 append(에버그린·유사도 뒤 마지막 두 스테이지)·추천 생성은 5.2. 클러스터는 휘발(4.4 재구축)이라 5.1은 4.4 뒤에 돌아 현재 클러스터에 점수를 쓴다.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: opportunity_score 컬럼 추가
- `bin/rails test test/services/scoring/calculate_opportunity_score_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)

## Auto Run Result

Status: done

**구현 요약** — `Scoring::CalculateOpportunityScore`가 각 `TopicCluster`(4.4)의 4입력을 **경쟁(is_own:false) 멤버**에서 집계·[0,1] 정규화(성과 min(배수/divisor,1)·공통성 min(경쟁채널수/cap,1)·갭 버킷값 평균·최신성 선형감쇠 clamp)하고 `scoring.yml` 가중치로 가중합 ×100해 `TopicCluster.opportunity_score`(0~100 clamp)로 배치 물질화한다. FR-21 구조 고정·파라미터 config(AD-4). 4입력 종합이라 성과 배수 단독 대체 없음. 자사 전용 클러스터(경쟁 신호 0)는 기회 0. 순수 계산·API 무관. 잡 체인 append·추천은 5.2.

**변경/신규 파일**
- `db/migrate/20260724100017_add_opportunity_score_to_topic_clusters.rb`
- `app/services/scoring/calculate_opportunity_score.rb`(신규)·`config/scoring.yml`(normalization 파라미터 채움)
- `test/services/scoring/calculate_opportunity_score_test.rb`(신규)·`db/schema.rb`

**리뷰 결과** — Blind + Edge Case 병렬. patch 3(recency 상한 clamp·score [0,100] clamp·경쟁 스코프 의미론 정렬로 own-only 0점), defer 0, reject 6(nil channel·config 0·서브해시 fetch·미반올림·no-data·N+1 — 불가능/큐레이션/구조고정/표시/AD-9/규모). intent_gap·bad_spec 0. capstone 지표의 실질 정렬이라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 14 runs/19 assertions, 전체 313 runs/996 assertions, 0 failures(회귀 없음). 성과 정규화·상한·갭 매핑·최신성 감쇠·하한·미래발행 clamp·공통성 상한·구조 불변(경쟁 성과 만점<100)·own-only 0점·nil 방어·물질화·결정성 검증. `proposal.html`·`config/scoring.yml`(별도 채움) 정합.

**잔여 리스크·결정** — 4입력 정규화 파라미터·가중치·클러스터 집계 방식은 잠정(FR-21 ASSUMPTION 본개발 실측 확정). 기회 점수 = 경쟁 신호 스코프(자사 기존 영상은 기회 아님)로 정렬. 추천 3개·정직성·결정적 동점·잡 체인 마지막 append는 5.2.
