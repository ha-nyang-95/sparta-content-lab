---
title: 'Story 4.2: 자사 유사영상 판정 (OwnVideoMatch)'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-1-embedding-upsert.md'
warnings: []
baseline_revision: '9cc5bd6c777c3aa5a88d0a030bc3b9ed26544a7e'
final_revision: '22d719ca0466437e442a174feff91d1cb1f477c3'
---

<intent-contract>

## Intent

**Problem:** 경쟁 영상이 다루는 주제를 자사가 이미 다뤘는지 알아야 콘텐츠 갭·추천이 가능하다. 자사/경쟁 영상을 임베딩 유사도로 매칭해야 한다. 단 자사 채널 표시 방식이 없었다(운영자 결정: `channels.is_own` 불리언).

**Approach:** `channels.is_own`(운영자 결정)으로 자사/경쟁을 파티션한다. `Similarity::MatchOwnVideos`(app/services/similarity 경계)가 4.1이 저장한 임베딩 BLOB(`Video#embedding_vector`)에 **완전 Ruby 코사인**(분모 계산, float32 저장이라 unit-norm 비가정)을 돌려 τ(`scoring.yml`) 이상 경쟁-자사 쌍을 `OwnVideoMatch(competitor_video, own_video, similarity)`로 배치 물질화한다(웹 요청 경로 아님). 회원 전용 자사 영상도 임베딩 있으면 매칭에 포함(성과 수치 미표시는 Epic 6).

## Boundaries & Constraints

**Always:**
- 유사도 로직은 `app/services/similarity` 경계에(AD-2). 임계 τ는 `Scoring::Config`로 `config/scoring.yml`의 `similarity.tau`에서만 읽는다(AD-4, 고정 0.8 하드코딩·맹신 금지).
- 자사/경쟁 파티션은 `channels.is_own`(boolean, null:false default false). own = `is_own: true` 채널의 영상, competitor = `is_own: false` 채널의 영상. `category` 4분류는 순수 필터 축으로 유지(자사 채널도 도메인 category 보유).
- 유사도 = `Video#embedding_vector`(unpack float32) 두 벡터의 **완전 코사인** `dot(a,b) / (‖a‖·‖b‖)`. **저장 벡터가 unit-norm이라 가정하지 않는다**(4.1 float32 드리프트 승계 — 분모를 반드시 계산). `Similarity::Cosine`로 분리(4.4 재사용).
- 임베딩 없는(`embedding` nil) 영상은 매칭에서 제외(AD-9 nil 방어). 차원 불일치 벡터 쌍은 스킵(방어).
- `OwnVideoMatch(competitor_video_id, own_video_id, similarity)` 물질화 — (competitor_video_id, own_video_id) 유니크. **배치 물질화**(웹 요청 경로 재계산 없음, AD-3). τ 이상 쌍만 기록. idempotent 재계산(재실행 시 현재 유사도로 재구축, 스테일 없음).
- 회원 전용(코스, `view_count` nil) 자사 영상도 **임베딩이 있으면 매칭에 포함**된다(제목·주제 매칭). 성과 수치 미표시는 Epic 6 표시 관심사 — 4.2는 매칭 물질화까지.

**Block If:**
- (없음 — 자사 표시 결정 완료(is_own). 순수 계산·저장 벡터 소비·API 무관.)

**Never:**
- τ 하드코딩. unit-norm 가정으로 분모 생략(float32 드리프트로 틀림). 임베딩 없는 영상 매칭.
- 자사/경쟁을 `category`로 판정(is_own 사용). 회원 전용 자사 영상을 매칭에서 제외(임베딩 있으면 포함).
- 잡 체인 append(4.4 담당). 콘텐츠 갭 버킷(4.3). 웹 요청 경로 유사도 계산. 화면·컨트롤러(Epic 6).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| τ 이상 매칭 | 경쟁·자사 임베딩 코사인 ≥ τ | OwnVideoMatch 기록(similarity) | — |
| τ 미만 | 코사인 < τ | 기록 안 함 | — |
| τ 경계 | 코사인 정확히 τ | 기록(포함 하한 >=) | — |
| 완전 코사인 | 비정규 벡터(‖·‖≠1) | 분모 계산해 올바른 코사인 | — |
| 임베딩 없음(경쟁) | competitor embedding nil | 매칭 제외 | AD-9 |
| 임베딩 없음(자사) | own embedding nil | 매칭 제외 | AD-9 |
| 회원전용 자사 | own view_count nil, embedding 있음 | 매칭 포함(성과 미표시는 Epic 6) | — |
| 자사↔자사 | own vs own | 매칭 안 함(경쟁-자사만) | — |
| 다대다 | 경쟁1 : 자사 다수 ≥ τ | 각 쌍 별 OwnVideoMatch | — |
| 재계산 | 이미 매칭 존재 | 현재 유사도로 재구축(스테일 없음) | — |
| 차원 불일치 | 두 벡터 길이 다름 | 그 쌍 스킵 | 방어 |

</intent-contract>

## Code Map

- `db/migrate/*_add_is_own_to_channels.rb` -- `channels.is_own` boolean null:false default false
- `db/migrate/*_create_own_video_matches.rb` -- `own_video_matches`(competitor_video_id, own_video_id, similarity, 유니크)
- `app/models/channel.rb` -- `is_own` 검증·`own`/`competitor` 스코프 추가
- `app/models/own_video_match.rb` -- `OwnVideoMatch`(belongs_to competitor_video·own_video, class_name Video)
- `app/models/video.rb` -- `#embedding_vector`(4.1, 소비)
- `app/services/similarity/cosine.rb` -- `Similarity::Cosine.between(a, b)` 완전 코사인(4.4 재사용)
- `app/services/similarity/match_own_videos.rb` -- `Similarity::MatchOwnVideos.call` 매칭·물질화
- `config/scoring.yml` -- `similarity.tau`(기존)
- `db/seeds.rb` -- 자사 채널 `@KankokugoBenkyo`(is_own: true) 추가
- `test/services/similarity/*`·`test/models/own_video_match_test.rb` -- 코사인·τ 경계·nil 방어·파티션·회원전용 포함

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_is_own_to_channels.rb` -- `add_column :channels, :is_own, :boolean, null: false, default: false` -- 자사/경쟁 파티션 -- `db:migrate && db:prepare`
- [x] `db/migrate/*_create_own_video_matches.rb` -- `create_table :own_video_matches`: `competitor_video`(references→videos, null:false), `own_video`(references→videos, null:false), `similarity`(float, null:false), timestamps. `add_index [:competitor_video_id, :own_video_id], unique: true` -- 매칭 물질화 -- 마이그레이션
- [x] `app/models/channel.rb` -- `validates :is_own, inclusion: { in: [true, false] }`; `scope :own, -> { where(is_own: true) }`; `scope :competitor, -> { where(is_own: false) }` -- 파티션 -- 파티션 AC
- [x] `app/models/own_video_match.rb` -- `belongs_to :competitor_video, class_name: "Video"`; `belongs_to :own_video, class_name: "Video"`; `validates :own_video_id, uniqueness: { scope: :competitor_video_id }` -- 물질화 대상 -- 모델
- [x] `app/services/similarity/cosine.rb` -- `Similarity::Cosine.between(a, b)`: nil이나 길이 불일치면 nil; 아니면 `dot / (norm_a * norm_b)`(분모 계산, norm 0이면 nil) -- 완전 코사인 AC
- [x] `app/services/similarity/match_own_videos.rb` -- `Similarity::MatchOwnVideos.new.call`: τ=`Scoring::Config.fetch(:similarity,:tau)`; own = `Video.joins(:channel).where(channels:{is_own:true}).where.not(embedding:nil)`, competitor = `is_own:false` + embedding 있음; 각 경쟁×자사 쌍 코사인 계산, ≥ τ면 매칭 수집; 트랜잭션으로 `OwnVideoMatch.delete_all`(또는 스코프) 후 `insert_all`(현재 매칭, idempotent 재구축) -- 매칭·물질화 AC
- [x] `db/seeds.rb` -- 자사 채널 `スパルタ韓国語 l 楽しく独学`(@KankokugoBenkyo, is_own: true, category 직접경쟁) 추가(idempotent) -- 자사 채널 등록
- [x] `test/services/similarity/*`·`test/models/own_video_match_test.rb` -- I/O 매트릭스(τ 경계·완전 코사인 비정규 벡터·nil 방어·차원 불일치·자사/경쟁 파티션·회원전용 자사 포함·idempotent 재구축) -- 검증

**Acceptance Criteria:**
- Given 임베딩이 있는 경쟁·자사 영상, when 배치가 유사도를 계산하면, then `OwnVideoMatch(competitor_video_id, own_video_id, similarity)`가 배치로 물질화된다(웹 요청 경로 아님).
- Given 두 임베딩, when 유사도를 계산하면, then 메모리로 올린 BLOB(`embedding_vector`)에 완전 Ruby 코사인(분모 ‖a‖‖b‖ 계산)으로 계산되고 저장 벡터가 unit-norm이라 가정하지 않는다.
- Given 임계 τ, when 읽으면, then `scoring.yml`의 `similarity.tau`에서 읽고(고정 0.8 하드코딩 아님) τ 이상 쌍만 기록한다.
- Given 코스(회원 전용, view_count nil) 자사 영상, when 매칭하면, then 임베딩이 있으면 매칭 결과에 포함된다(성과 수치 미표시는 Epic 6 표시).
- Given `embedding`이 nil인 영상, when 매칭하면, then 예외 없이 매칭에서 제외된다.
- Given 자사/경쟁 구분, when 파티션하면, then `channels.is_own`으로 나누고 `category`(4분류)는 필터 축으로 유지한다.

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 5: (high 2, medium 3, low 0)
- defer: 0
- reject: 1: (low 1)
- addressed_findings:
  - `[high]` `[patch]` `match_own_videos.rb` 파티션이 `excluded` 채널 미필터 — RecordDailyStats·스코어링·모델 주석("excluded 제외") 불변식 위반. own/competitor 쿼리에 `excluded: false` 추가.
  - `[high]` `[patch]` `match_own_videos.rb` own/competitor 집합 일시 empty(임베딩 대기) 시 `delete_all`이 유효 매칭 전량 삭제. 한쪽 empty면 재구축 no-op(스테일 방지).
  - `[medium]` `[patch]` `cosine.rb`·`match_own_videos.rb` Cosine가 pair마다 norm 재계산(N×M sqrt)·zip 할당, NaN 미필터·[-1,1] 미clamp. `unit`(벡터당 1회 정규화)·`dot` 분리로 재계산 제거 + `finite?`·`clamp(-1,1)`.
  - `[medium]` `[patch]` `db/seeds.rb` 자사 파티션이 seed 1행 is_own 의존이나 create 블록만 실행 — 기존 행(발굴·수동으로 is_own:false 생성) 복구 불가. 자사 채널 행 `is_own=true` 무조건 복구.
  - `[medium]` `[patch]` `match_own_videos.rb` `insert_all` 미배치 — SQLite 변수 한도 초과 시 크래시. `each_slice(500)` 배치.
- rejected(noise): 차원 불일치 무신호 로그(4.1 provenance 해시가 차원 변경 시 전량 재임베딩 → 혼합 차원 미지속·자가치유, 스킵은 올바른 방어).

## Design Notes

**자사/경쟁 = is_own(운영자 결정).** 자사 채널 표시 방식이 플래닝·스키마에 없던 진짜 갭이었다. 운영자가 `channels.is_own` 불리언을 택했다(category 5번째값·config 지정 대신). own=`is_own:true` 영상, competitor=`is_own:false` 영상. `category` 4분류는 순수 필터/그룹핑 축으로 유지(자사 채널도 도메인 category=직접경쟁 보유). 실제 자사 채널 `@KankokugoBenkyo`를 seed에 is_own:true로 등록.

**완전 코사인(4.1 승계).** `Similarity::Cosine.between(a,b) = dot / (‖a‖·‖b‖)`. 저장 벡터는 float32 pack/unpack이라 정확한 단위 벡터가 아니다(≈1e-7 드리프트) — 분모를 반드시 계산한다(unit-norm 가정으로 분모 생략 금지). nil·길이 불일치·norm 0 방어(nil 반환→스킵). `Similarity::` 도메인으로 분리해 4.4 주제 클러스터가 같은 코사인을 재사용한다(추가 임베딩 비용 없음).

**회원 전용 자사 영상 포함.** 자사 간판 콘텐츠(코스)는 회원 전용이라 `view_count` nil이지만 제목 임베딩은 있다. 매칭은 임베딩(제목) 기반이라 이들도 own 집합에 포함된다 — "이미 다룬 주제인가"에 코스도 답해야 하기 때문. 성과 수치(view_count nil) 미표시는 Epic 6 표시 관심사이지 매칭 제외 사유가 아니다.

**idempotent 재구축.** 배치는 τ 이상 현재 쌍으로 `OwnVideoMatch`를 재구축한다(트랜잭션 내 delete_all + insert_all) — 유사도가 τ 아래로 떨어진 스테일 매칭을 남기지 않는다. 잡 직렬 실행 전제(기존 패턴). 잡 체인 append는 4.4.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: is_own·own_video_matches 생성
- `bin/rails test test/services/similarity test/models/own_video_match_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "p Similarity::Cosine.between([1.0,0.0],[1.0,0.0]); p Similarity::Cosine.between([1.0,0.0],[0.0,1.0])"` -- expected: `1.0` 그리고 `0.0`

## Auto Run Result

Status: done

**구현 요약** — `channels.is_own`(운영자 결정)으로 자사/경쟁 파티션. `Similarity::MatchOwnVideos`가 4.1 저장 임베딩 BLOB(`Video#embedding_vector`)에 완전 코사인(`Similarity::Cosine` — 벡터당 1회 단위 정규화 후 내적, unit-norm 비가정·finite·clamp)을 돌려 τ(`scoring.yml`) 이상 경쟁×자사 쌍을 `OwnVideoMatch`로 배치 idempotent 재구축(트랜잭션 delete_all + 배치 insert_all). excluded 채널 제외, 한쪽 empty면 재구축 skip(스테일 방지). 회원 전용 자사 영상도 임베딩 있으면 포함. 잡 체인 append는 4.4.

**변경/신규 파일**
- `db/migrate/20260724100012_add_is_own_to_channels.rb`·`20260724100013_create_own_video_matches.rb`
- `app/models/channel.rb`(is_own 검증·own/competitor 스코프)·`own_video_match.rb`(신규)
- `app/services/similarity/cosine.rb`·`match_own_videos.rb`(신규)
- `db/seeds.rb`(자사 채널 @KankokugoBenkyo is_own:true·복구), `db/schema.rb`
- `test/services/similarity/*`·`test/models/own_video_match_test.rb`

**리뷰 결과** — Blind + Edge Case 병렬. patch 5(excluded 필터·empty 재구축 가드·코사인 norm precompute+finite/clamp·seed is_own 복구·배치 insert_all), defer 0, reject 1(차원 불일치 — 4.1 provenance 자가치유). intent_gap·bad_spec 0. 정합+스케일 광범위라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 28 runs/53 assertions, 전체 277 runs/925 assertions, 0 failures(회귀 없음). τ 경계·완전 코사인 비정규 벡터·nil 방어·excluded 제외·empty 가드·회원전용 포함·다대다·idempotent·스테일 제거·NaN/clamp 검증. `proposal.html` 미변경.

**잔여 리스크·결정** — 자사 채널 표시는 `channels.is_own` 불리언(운영자 결정, 4.3·4.4·5.x 파급). 성과 수치 미표시(회원 전용)는 Epic 6 표시. 잡 체인 append·콘텐츠 갭 버킷·클러스터는 4.3·4.4. 실 임베딩은 4.1 보류(키 대기).
