---
title: 'Story 4.4: 임베딩 기반 주제 자동 묶기 (연결요소) + Epic 4 스테이지 체인 append'
type: 'feature'
created: '2026-07-24'
status: 'in-review'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-2-own-video-match.md'
warnings: []
baseline_revision: '20801296b0112e384f3b1214516d3dc6f1dc64ce'
final_revision: 'bb8515e005a1a8236cd58df47fdda1002cd938c5'
---

<intent-contract>

## Intent

**Problem:** 추천이 개별 영상이 아니라 주제 단위여야 한다. 임베딩 유사도로 영상을 주제로 자동 묶어야 하고, Epic 4 스테이지들이 아직 일일 잡에 연결되지 않았다.

**Approach:** `Similarity::BuildTopicClusters`(app/services/similarity 경계)가 임베딩 있는 영상들 중 코사인 유사도 ≥ τ(`scoring.yml`, FR-17 재사용) 쌍을 간선으로 잇고 **연결 요소(union-find)**를 하나의 `TopicCluster`로 물질화한다 — 배치마다 재계산되는 **휘발성**(AD-10, relatedToVideoId 미사용). `Similarity::Cosine`(4.2) 재사용이라 추가 임베딩 비용 0. 그리고 Epic 4 스테이지(임베딩 → OwnVideoMatch → 콘텐츠 갭 → 주제 클러스터)를 `DailyCollectionJob` 체인의 에버그린 후보 뒤에 순서대로 append한다(AD-11). 순수 계산·API 무관.

## Boundaries & Constraints

**Always:**
- 묶기 로직은 `app/services/similarity` 경계에(AD-2). τ는 `Scoring::Config`로 `config/scoring.yml`의 `similarity.tau`에서만 읽는다(FR-17 재사용, AD-4, 고정 0.8 맹신 금지).
- 대상 = **임베딩 있는(`embedding` non-nil) not_excluded 영상**(자사+경쟁, 일·한 교차). 간선 = `Similarity::Cosine`(완전 코사인, unit-norm 비가정) ≥ τ 인 쌍. **연결 요소**(union-find)를 하나의 클러스터로 본다. 임베딩 없는 영상 제외(AD-9). 스냅샷 불요(임베딩 의존, 1일차 동작).
- `TopicCluster`는 **휘발성** — 배치마다 `delete_all` 후 재구축(AD-10). `videos.topic_cluster_id`(FK nullable)로 멤버십, 재구축 시 먼저 nullify 후 클러스터 삭제(FK 위반 방지). `Recommendation`(Epic 5)은 휘발 클러스터에 FK하지 않고 스냅샷 저장 — 4.4는 클러스터 물질화까지.
- **묶기**는 2개 이상 영상의 그룹만 클러스터로 물질화(크기 1 고립 영상은 클러스터 아님, topic_cluster_id nil). 결정적(멤버 최소 id 기준 정렬·union-find 안정).
- 잡 체인 append(AD-11): `DailyCollectionJob`이 에버그린(3.4) 뒤에 **전역 배치** Epic 4 스테이지를 순서대로 호출 — `Embedding::UpsertVectors` → `Similarity::MatchOwnVideos` → `Similarity::ClassifyContentGap` → `Similarity::BuildTopicClusters`. 잡은 조립만(로직은 서비스). 스테이지별 rescue로 한 스테이지 실패가 나머지·런을 버리지 않음(파생·다음 런 재계산).

**Block If:**
- (없음 — 순수 로직·저장 벡터 소비·API 무관.)

**Never:**
- τ 하드코딩·별 임계 사용(FR-17 τ 재사용). unit-norm 가정(4.1 float32 승계 — 완전 코사인). `relatedToVideoId`·YouTube 관련영상 API. `Recommendation`이 휘발 `TopicCluster`에 FK.
- 잡에 묶기 로직 복제(AD-11 위임). 웹 요청 경로 계산. 화면(Epic 6). 기회 점수·추천(Epic 5).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 연결요소 | A-B, B-C 간선(≥τ), D 고립 | {A,B,C} 한 클러스터, D 클러스터 없음 | — |
| τ 경계 간선 | 코사인 정확히 τ | 간선 연결(포함 하한 >=) | — |
| τ 미만 | 코사인 < τ | 간선 없음 | — |
| 임베딩 없음 | embedding nil 영상 | 대상 제외 | AD-9 |
| excluded | excluded 채널 영상 | 대상 제외 | — |
| 고립 영상 | 간선 0개 영상 | 클러스터 아님(topic_cluster_id nil) | — |
| 휘발 재계산 | 재실행(임베딩 변화) | delete_all 후 현재 그래프로 재구축 | — |
| 교차 묶기 | 자사·경쟁 영상 유사 | 한 클러스터에 함께 | — |
| 결정성 | 같은 그래프 | 같은 멤버십(최소 id 기준) | — |
| 체인 append | 잡 실행 | 에버그린 뒤 임베딩→매치→갭→클러스터 순 | 스테이지별 rescue |

</intent-contract>

## Code Map

- `db/migrate/*_create_topic_clusters.rb` -- `topic_clusters`(id, size) + `videos.topic_cluster_id`(FK nullable, index)
- `app/models/topic_cluster.rb` -- `TopicCluster`(has_many videos, dependent: nullify)
- `app/models/video.rb` -- `belongs_to :topic_cluster, optional: true`(추가)
- `app/services/similarity/cosine.rb` -- `unit`·`dot`(4.2, 재사용)
- `app/services/similarity/build_topic_clusters.rb` -- `Similarity::BuildTopicClusters.call` union-find·재구축
- `app/jobs/daily_collection_job.rb` -- 에버그린 뒤 Epic 4 스테이지 append(전역·스테이지별 rescue)
- `config/scoring.yml` -- `similarity.tau`(기존)
- `test/services/similarity/build_topic_clusters_test.rb`·`test/jobs/daily_collection_job_test.rb` -- 연결요소·τ·nil·휘발·체인 순서

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_create_topic_clusters.rb` -- `create_table :topic_clusters`(t.integer :size, timestamps); `add_reference :videos, :topic_cluster, foreign_key: true, index: true`(nullable) -- 클러스터·멤버십 -- `db:migrate && db:prepare`
- [x] `app/models/topic_cluster.rb` -- `TopicCluster < ApplicationRecord`; `has_many :videos, dependent: :nullify` -- 휘발 클러스터 -- 모델
- [x] `app/models/video.rb` -- `belongs_to :topic_cluster, optional: true`(기존 라인 불변) -- 멤버십
- [x] `app/services/similarity/build_topic_clusters.rb` -- `Similarity::BuildTopicClusters.new.call`: τ 로드; `Video.joins(:channel).where(channels:{excluded:false}).where.not(embedding:nil).order(:id)` 각 영상 unit 벡터 1회; i<j 쌍 `Cosine.dot(unit_i,unit_j) >= τ`면 union; 크기≥2 연결요소만 → 트랜잭션 내 `Video.where.not(topic_cluster_id:nil).update_all(topic_cluster_id:nil)`·`TopicCluster.delete_all`·컴포넌트별 `TopicCluster.create!(size:)`+`Video.where(id: members).update_all(topic_cluster_id:)`. 결정적(최소 id 정렬) -- 묶기 AC
- [x] `app/jobs/daily_collection_job.rb` -- 스코어링 루프 뒤(스코어링 정상 시) Epic 4 스테이지 순서 호출: UpsertVectors→MatchOwnVideos→ClassifyContentGap→BuildTopicClusters. 스테이지별 rescue+로그. 조립만 -- 체인 append AC
- [x] `test/services/similarity/build_topic_clusters_test.rb`·`test/jobs/daily_collection_job_test.rb` -- I/O 매트릭스(연결요소·τ 경계·nil/excluded 제외·고립·휘발 재구축·교차·결정성) + 잡 체인 Epic 4 스테이지 물질화·순서 -- 검증

**Acceptance Criteria:**
- Given 임베딩이 있는 영상들, when 주제 묶기를 실행하면, then 코사인 유사도 ≥ τ(FR-17 재사용) 쌍을 간선으로 잇고 연결 요소를 하나의 `TopicCluster`로 물질화한다.
- Given 묶기, when 실행하면, then 스냅샷이 아니라 임베딩에 의존해 1일차부터 동작하고 추가 임베딩 비용이 없다(같은 인프라 재사용).
- Given `TopicCluster`, when 배치가 재실행되면, then 휘발적으로 재계산(재구축)되고 `relatedToVideoId`를 쓰지 않는다.
- Given Epic 4 스테이지, when `DailyCollectionJob`이 실행되면, then 에버그린 후보 뒤에 임베딩 → OwnVideoMatch → 콘텐츠 갭 버킷 → 주제 클러스터 순서로 append된다.
- Given 임베딩 없는 영상, when 묶기를 실행하면, then 예외 없이 대상에서 제외된다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 1: (high 0, medium 1, low 0)
- defer: 0
- reject: 7: (low 7)
- addressed_findings:
  - `[medium]` `[patch]` `build_topic_clusters.rb` 4.2 `MatchOwnVideos`의 `return if empty` 가드 누락 — 임베딩 일시 전량 부재 시 `delete_all`이 유효 클러스터 전량 삭제. `return if units.empty?` 추가(대칭·스테일 방지) + 테스트.
- rejected(noise): per-stage rescue가 retry_on Deadlocked 무력화(기존 fetch/scoring 루프와 동일 의도적 per-item rescue·유사도 idempotent·다음 런 회복), 상류 실패 stale 하류(best-effort 파생·로그 관측·수집이 런 성공 축), 스코어링 실패 시 유사도 skip(방어적 fail-fast·ClassifyContentGap은 VideoScore 의존이기도), O(N²) pairwise(AD-10이 BLOB+Ruby 코사인을 5만 벡터까지 수용·전환점 명시), 단일연결 전이 체이닝(AC가 '연결 요소' 명시·by-design), τ clamp 불일치(τ=0.8에선 무의미·±1 근처만 영향·τ가 1.0 근처로 튜닝될 때만 latent), dependent:nullify 대 delete_all(현 코드 수동 nullify로 정확·association은 타 삭제 경로용).

## Design Notes

**연결요소 = union-find.** 임베딩 있는 not_excluded 영상을 노드로, 코사인 ≥ τ 쌍을 간선으로 union-find해 연결 요소를 낸다. `Similarity::Cosine.unit`으로 영상당 1회 정규화하고 `dot`로 쌍 코사인(완전 코사인, 4.1 float32 승계라 unit-norm 비가정). 크기 1 고립 영상은 "묶기"가 아니므로 클러스터로 물질화하지 않는다(topic_cluster_id nil) — 크기≥2 그룹만. 결정적: 노드·컴포넌트를 최소 id 기준으로 정렬해 재실행 안정.

**휘발성 재구축(AD-10).** `TopicCluster`는 배치마다 재계산된다 — 트랜잭션 내에서 `videos.topic_cluster_id`를 먼저 nullify(FK 위반 방지) → `TopicCluster.delete_all` → 현재 그래프로 재생성. `Recommendation`(Epic 5)은 이 휘발 클러스터에 FK하지 않고 생성 시점 reference_video_ids+topic_label을 스냅샷 저장하므로 재라벨링에도 댕글링되지 않는다 — 그 소비는 Epic 5. 4.2 `OwnVideoMatch` delete_all+rebuild와 같은 휘발 패턴.

**체인 append(AD-11).** Epic 4 스테이지는 채널 무관 **전역 배치**라, 3.4의 채널별 스코어링 루프 뒤에 전역으로 순서 호출한다(임베딩→매치→갭→클러스터). 잡은 조립만. 스테이지별 rescue로 한 스테이지 실패를 격리(파생·idempotent라 다음 런 재계산). 스코어링이 체계적 실패한 런에서는 Epic 4 스테이지를 건너뛰고 failed 기록(3.4 정직성 흐름 유지). 이로써 일일 체인은 수집→스냅샷→스코어링(Epic 3)→유사도(Epic 4)까지 완성되고, Epic 5 기회점수·추천이 마지막에 붙는다.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: topic_clusters·videos.topic_cluster_id 생성
- `bin/rails test test/services/similarity/build_topic_clusters_test.rb test/jobs/daily_collection_job_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "DailyCollectionJob.perform_now; p [Video.where.not(embedding: nil).count, TopicCluster.count, JobRun.last.status]"` -- expected: 임베딩·(가능 시)클러스터·succeeded

## Auto Run Result

Status: done

**구현 요약** — `Similarity::BuildTopicClusters`가 임베딩 있는 not_excluded 영상(자사+경쟁, 일·한 교차)을 노드로, 코사인 ≥ τ(`scoring.yml`, FR-17 재사용) 쌍을 간선으로 union-find(경로 압축·최소 id 대표)해 연결 요소를 휘발성 `TopicCluster`로 배치 재구축한다(트랜잭션 nullify→delete_all→재생성, 크기≥2만, `Similarity::Cosine` 재사용이라 추가 임베딩 비용 0). `DailyCollectionJob`이 에버그린(3.4) 뒤에 Epic 4 전역 스테이지(임베딩→OwnVideoMatch→콘텐츠 갭→주제 클러스터)를 스테이지별 rescue로 순서 append(AD-11, 조립만). 순수 계산·API 무관.

**변경/신규 파일**
- `db/migrate/20260724100016_create_topic_clusters.rb`(topic_clusters + videos.topic_cluster_id FK)
- `app/models/topic_cluster.rb`(신규)·`app/models/video.rb`(belongs_to topic_cluster)
- `app/services/similarity/build_topic_clusters.rb`(신규)
- `app/jobs/daily_collection_job.rb`(run_similarity_stages 전역 append)
- `test/services/similarity/build_topic_clusters_test.rb`(신규)·`test/jobs/daily_collection_job_test.rb`(추가)·`db/schema.rb`

**리뷰 결과** — Blind + Edge Case 병렬. patch 1(임베딩 전량 부재 시 empty 가드 — 4.2 대칭·스테일 방지), defer 0, reject 7(retry_on·상류 stale·스코어링 커플링·O(N²)·전이 체이닝·clamp·nullify — 기존 패턴 정합이거나 AD-10/AC by-design). intent_gap·bad_spec 0. Epic 4 유사도 체인을 프로덕션 일일 잡에 통합하는 finale라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 17→ 재실행 후 전체 299 runs/977 assertions, 0 failures(회귀 없음). 연결요소(A-B-C 한 클러스터·D 별개)·τ 경계·nil/excluded 제외·고립 미클러스터·휘발 재구축·임베딩 전량 부재 가드·교차 묶기·결정성·잡 체인 Epic 4 스테이지 append(에버그린 뒤 임베딩 물질화·succeeded) 검증. `proposal.html`·`config/scoring.yml` 미변경.

**잔여 리스크·완결** — Epic 4 유사도 엔진 완결. 일일 체인은 수집→스냅샷→스코어링(Epic 3)→유사도(Epic 4)까지 완성, Epic 5 기회점수·추천이 마지막에 붙는다. TopicCluster는 휘발(Recommendation은 reference_video_ids+topic_label 스냅샷, Epic 5 소비). 실 임베딩은 4.1 보류(키 대기). O(N²)는 5만 벡터 초과 시 sqlite-vec 전환(AD-10).
