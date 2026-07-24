---
title: 'Story 4.3: 콘텐츠 갭 4구간 버킷'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-4-2-own-video-match.md'
warnings: []
baseline_revision: 'e84c1e2a8e98e5a0a2182f9927d9f49c6d09356d'
final_revision: 'd2f273d9ddd884869356d5c73ece8312b9773a93'
---

<intent-contract>

## Intent

**Problem:** 경쟁 영상 주제를 자사가 얼마나 다뤘는지 한눈에 봐야 콘텐츠 공백을 찾는다. 4.2가 만든 자사 유사영상 매칭 개수를 4구간으로 분류해야 한다.

**Approach:** `Similarity::ClassifyContentGap`(app/services/similarity 경계)가 각 경쟁 영상의 `OwnVideoMatch` 개수를 세어 4구간(미제작/유사영상 1개/유사영상 2개+/포화)으로 분류해 `VideoScore.content_gap_bucket`으로 배치 물질화한다. 급상승 영상 행(같은 `VideoScore`)과 같은 개수를 쓰므로 표시가 반드시 일치한다(FR-18 AC). '포화' 임계는 `scoring.yml`(AD-4). 순수 계산·API 무관.

## Boundaries & Constraints

**Always:**
- 분류 로직은 `app/services/similarity` 경계에(AD-2). '포화' 임계는 `Scoring::Config`로 `config/scoring.yml`의 `content_gap.saturation_min`에서만 읽는다(AD-4, 하드코딩 금지).
- 각 **경쟁 영상**(`channels.is_own: false`, not excluded)을 그 영상의 `OwnVideoMatch` 개수로 분류: `0 → not_made`(미제작), `1 → one`(유사영상 1개), `2..(saturation_min-1) → few`(유사영상 2개+), `>= saturation_min → saturated`(포화). 4구간은 상호배타·전수 커버.
- 개수는 4.2 `OwnVideoMatch`(competitor_video_id 기준)의 개수다 — 급상승 영상 행이 표시하는 "자사 유사영상(없음/N개)"과 **동일 개수·동일 소재지**(`VideoScore` 같은 행)라 표시가 어긋나지 않는다(FR-18 AC).
- `VideoScore.content_gap_bucket`(string) 물질화 — 경쟁 영상의 VideoScore에만 설정. **배치**(웹 요청 경로 재계산 없음, AD-3). idempotent 재계산(재실행 시 현재 개수로 갱신). 결정적.
- OwnVideoMatch 0개 경쟁 영상도 명시적으로 `not_made`로 분류(nil 아님). 3.2 `CalculatePerformance.update!`가 이 컬럼을 건드리지 않으므로 스테이지 간 보존.

**Block If:**
- (없음 — 순수 로직·기존 스키마 확장·API 무관.)

**Never:**
- 자사 영상을 분류(경쟁 영상만 — 자사 VideoScore의 content_gap_bucket은 nil 유지). 개수를 급상승 행과 다른 소재지에서 재계산(불일치 위험).
- 잡 체인 append(4.4 담당). 도넛·화면 렌더(Epic 6). saturation_min 하드코딩. 웹 요청 경로 분류.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 미제작 | 경쟁 영상 OwnVideoMatch 0개 | content_gap_bucket = not_made | — |
| 유사 1개 | 매치 1개 | one | — |
| 2개+ | 매치 2개(saturation_min=3) | few | — |
| 포화 경계 | 매치 = saturation_min | saturated(포함 하한 >=) | — |
| 포화 미달 경계 | 매치 = saturation_min-1 | few | — |
| 경쟁만 | 자사 영상 VideoScore | content_gap_bucket nil(분류 안 함) | — |
| excluded | excluded 채널 경쟁 영상 | 분류 안 함(정합) | — |
| 재계산 | 매치 수 변화 후 재실행 | 현재 개수로 버킷 갱신 | — |
| 스테이지 보존 | performance 재실행 | content_gap_bucket 유지 | — |
| VideoScore 없음 | is_short nil 경쟁 영상(VideoScore 없음) | 분류 대상 아님(급상승 행에도 없음) | — |

</intent-contract>

## Code Map

- `db/migrate/*_add_content_gap_bucket_to_video_scores.rb` -- `video_scores.content_gap_bucket` string
- `app/models/video_score.rb` -- `CONTENT_GAP_BUCKETS` 상수(참조용)
- `app/models/own_video_match.rb` -- 개수 소스(4.2, 재사용)
- `app/services/similarity/classify_content_gap.rb` -- `Similarity::ClassifyContentGap.call` 분류·물질화
- `config/scoring.yml` -- `content_gap.saturation_min`(기존에 추가)
- `test/services/similarity/classify_content_gap_test.rb` -- 4구간 경계·경쟁만·idempotent·보존

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_content_gap_bucket_to_video_scores.rb` -- `add_column :video_scores, :content_gap_bucket, :string`(nullable) -- 버킷 물질화 자리 -- `db:migrate && db:prepare`
- [x] `app/models/video_score.rb` -- `CONTENT_GAP_BUCKETS = %w[not_made one few saturated].freeze`(참조·검증용, 기존 라인 불변) -- 상수
- [x] `app/services/similarity/classify_content_gap.rb` -- `Similarity::ClassifyContentGap.new.call`: `sat = Scoring::Config.fetch(:content_gap, :saturation_min)`; 경쟁 영상 VideoScore(`joins(video: :channel).where(channels:{is_own:false, excluded:false})`) 각각에 대해 `count = OwnVideoMatch.where(competitor_video_id: score.video_id).count`; `bucket = classify(count, sat)`(0→not_made,1→one,2..sat-1→few,≥sat→saturated); `score.update!(content_gap_bucket: bucket)`. 전체 트랜잭션 -- 분류·물질화 AC
- [x] `test/services/similarity/classify_content_gap_test.rb` -- I/O 매트릭스(0/1/2/경계 saturation_min·경쟁만·excluded 제외·idempotent·보존) -- 검증

**Acceptance Criteria:**
- Given `OwnVideoMatch`가 물질화된 경쟁 영상, when 콘텐츠 갭을 분류하면, then 각 경쟁 영상이 미제작/유사영상 1개/유사영상 2개+/포화 4구간으로 분류·물질화된다.
- Given 분류 개수, when 급상승 영상 행의 자사 유사영상(없음/N개) 컬럼과 비교하면, then 같은 `OwnVideoMatch` 개수·같은 `VideoScore` 행이라 분류가 반드시 일치한다.
- Given '포화' 임계, when 읽으면, then `scoring.yml`의 `content_gap.saturation_min`에서 읽고 하드코딩하지 않는다.
- Given OwnVideoMatch 0개 경쟁 영상, when 분류하면, then 명시적으로 `not_made`로 분류된다(nil 아님).
- Given 자사 영상, when 분류하면, then 콘텐츠 갭 분류 대상이 아니다(경쟁 영상만).

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 2: (high 1, medium 0, low 1)
- defer: 0
- reject: 5: (low 5)
- addressed_findings:
  - `[high]` `[patch]` `classify_content_gap.rb`·`VideoScore` 버킷만 물질화하고 개수(N)를 저장 안 함 → FR-18 "일치" AC 미보장(Epic 6가 "N개"를 독립 재계산 → AD-3 위반·다른 시점 count로 버킷과 어긋남). `own_match_count`(integer) 컬럼 추가 + 단일 grouped count 로 개수·버킷을 같은 VideoScore 행에 함께 물질화(N+1도 제거).
  - `[low]` `[patch]` `VideoScore` `content_gap_bucket` inclusion 검증 부재 — classify 오타가 조용히 영속. `CONTENT_GAP_BUCKETS` 화이트리스트 검증(allow_nil).
- rejected(noise): excluded 후 stale 버킷(전 앱 공통 — performance_multiple·evergreen도 excluded 시 동결·Epic 6가 not_excluded 필터하는 관례, content_gap만 clear하면 비대칭), 개수에 stale own 매칭 포함(4.2가 매 런 delete_all+rebuild로 유효 매칭만 유지·4.4가 MatchOwnVideos→ClassifyContentGap 순서 보장·런 내 fresh), saturation_min 오설정 무가드(큐레이션 config·타 scoring.yml 값들도 무가드·sat<=2 few empty는 유효 선택), VideoScore 없는 경쟁 영상 미분류(by-design·급상승 행도 VideoScore 키), 단일 트랜잭션 rescue(원자 리프레시 의도·4.2 MatchOwnVideos 정합).

## Design Notes

**물질화 = VideoScore 컬럼(같은 행 = 표시 일치).** FR-18 AC는 콘텐츠 갭 분류가 급상승 영상 행의 "자사 유사영상(없음/N개)" 컬럼과 반드시 일치할 것을 요구한다. 급상승 행은 `VideoScore`(performance_multiple·rank_eligible)를 렌더하므로, `content_gap_bucket`과 **개수 `own_match_count`(정수)를 같은 `VideoScore` 행에 함께** 둔다 — Epic 6이 "N개"를 `own_match_count`로 읽고 버킷도 같은 개수에서 파생돼 두 표시가 구조적으로 일치한다(AD-3: 웹 요청 경로는 저장값을 읽기만, 재계산 금지). 개수를 저장하지 않고 버킷만 두면 Epic 6이 독립 count를 다른 시점에 재계산해 버킷과 어긋날 수 있어 금지. 개수는 단일 grouped count(`OwnVideoMatch.group(:competitor_video_id).count`)로 얻어 N+1을 피한다. 경쟁 영상의 VideoScore에만 설정하고 자사 영상은 nil로 둔다.

**4구간 = 개수 임계.** `not_made(0)/one(1)/few(2..sat-1)/saturated(≥sat)`. `few`가 "유사영상 2개+"의 UX 라벨(2부터 포화 직전), `saturated`가 "포화"다. '포화' 임계 `saturation_min`(잠정 3)은 `scoring.yml` 단일 소재지의 튜닝값 — PRD가 '2개+'와 '포화'의 개수 경계를 수치로 못박지 않았으므로 스파인은 자리만 고정(본개발 실측 확정, AD-4). 개수는 4.2 `OwnVideoMatch`(competitor 기준) count 그대로 — 급상승 행 "N개"와 동일.

**스테이지 보존·범위.** 3.2 `CalculatePerformance`는 3컬럼만 update! 하므로 `content_gap_bucket`은 스테이지 간 보존된다(에버그린 패턴 동일). is_short nil이라 VideoScore가 없는 경쟁 영상은 분류 대상이 아니며 급상승 테이블에도 없다(일관). 잡 체인 append는 4.4.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: content_gap_bucket 컬럼 추가
- `bin/rails test test/services/similarity/classify_content_gap_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)

## Auto Run Result

Status: done

**구현 요약** — `Similarity::ClassifyContentGap`이 각 경쟁 영상(is_own:false, not excluded)의 `OwnVideoMatch` 개수를 단일 grouped count로 세어 4구간(not_made/one/few/saturated, '포화' 임계 `scoring.yml` `content_gap.saturation_min`)으로 분류하고, **개수(`own_match_count`)와 버킷(`content_gap_bucket`)을 같은 `VideoScore` 행에 함께 배치 물질화**한다. Epic 6이 급상승 행 "N개"를 `own_match_count`로, 도넛을 버킷으로 읽어 두 표시가 구조적으로 일치(FR-18). 순수 계산·API 무관. 잡 체인 append는 4.4.

**변경/신규 파일**
- `db/migrate/20260724100014_add_content_gap_bucket_to_video_scores.rb`·`20260724100015_add_own_match_count_to_video_scores.rb`
- `app/models/video_score.rb`(CONTENT_GAP_BUCKETS·inclusion 검증)
- `app/services/similarity/classify_content_gap.rb`(신규)·`config/scoring.yml`(content_gap.saturation_min)
- `test/services/similarity/classify_content_gap_test.rb`(신규)·`db/schema.rb`

**리뷰 결과** — Blind + Edge Case 병렬. patch 2(개수 own_match_count 물질화로 FR-18 구조적 일치+N+1 제거·버킷 inclusion 검증), defer 0, reject 5(excluded stale·stale own 매칭·config 무가드·VideoScore 없는 경쟁 영상·단일 트랜잭션 — 전 앱 공통이거나 4.2/4.4가 보장·by-design). intent_gap·bad_spec 0. 개수 물질화가 스키마·설계 변경이라 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 12 runs/18 assertions, 전체 289 runs/943 assertions, 0 failures(회귀 없음). 0/1/2/포화 경계·경쟁만·excluded 제외·idempotent·스테이지 보존·개수 동시 물질화·버킷 화이트리스트 검증. `proposal.html` 미변경.

**잔여 리스크** — saturation_min(잠정 3)은 본개발 실측 튜닝. 도넛·화면 렌더는 Epic 6(not_excluded 필터). 잡 체인 append는 4.4. 실 임베딩은 4.1 보류.
