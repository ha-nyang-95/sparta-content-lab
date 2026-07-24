---
title: 'Story 4.1: 임베딩 생성·저장 (제목 변경 시만 재생성)'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
warnings: []
baseline_revision: '7d97cab89928ac0ce35beef49aa018734c0cd183'
final_revision: '9bc72c92bf1870062bcd88a2e18a91b8a12730a1'
---

<intent-contract>

## Intent

**Problem:** 유사영상·주제 묶기(4.2~4.4)를 하려면 영상 제목 임베딩이 필요하다. 임베딩은 유료(Gemini)라 신규·제목 변경 영상만 재생성해 과금을 최소화해야 하고, 아직 API 키가 없어 스텁으로 개발해야 한다.

**Approach:** `Embedding` 경계(2.2 Youtube 패턴 그대로: Config·Client·adapters stub/live·errors)가 제목 임베딩을 생성한다 — **stub은 제목에서 결정적 벡터를 만들고 STUB 로그로 '아직 진짜 아님'을 표시**, live(`gemini-embedding-001`)는 **보류(키 대기)**. `Embedding::UpsertVectors` 배치가 `videos`의 packed-float BLOB 컬럼에 벡터를, `embedding_source_hash`(제목 기준)에 해시를 저장하고 **신규 또는 해시가 바뀐 행만 재생성**한다(과금은 여기에만). sqlite-vec 미채택(BLOB + Ruby 코사인, AD-10).

## Boundaries & Constraints

**Always:**
- Gemini 호출은 `app/services/embedding` 경계에서만(AD-1). 모드·키·모델·차원은 `Embedding::Config`로 ENV(`EMBEDDING_MODE`/`GEMINI_API_KEY`/`GEMINI_EMBEDDING_MODEL`)→credentials에서만 읽는다. 코드 하드코딩 금지.
- **키 대기 스텁 전략:** `EMBEDDING_MODE`(기본 stub)로 stub/live 분기(Youtube::Config.mode 패턴). **stub 어댑터는 매 호출 STUB 로그**로 진짜 아님을 표시하고 제목에서 **결정적** 벡터(같은 제목→같은 벡터)를 만든다. **live 어댑터는 실 Gemini HTTP·타임아웃이되 보류(키 대기)** — 키 없으면 `Embedding::ConfigurationError`.
- 임베딩 저장: `videos.embedding`(packed-float BLOB, `Array#pack("f*")`)·`videos.embedding_source_hash`(제목 SHA-256). 벡터 차원은 stub·live 동일(`Embedding::Config.dimensions`, 실 `gemini-embedding-001` 지원 차원). **sqlite-vec 미채택** — BLOB + Ruby 코사인(AD-10).
- **제목 변경 시에만 재생성(과금 최소화):** `Embedding::UpsertVectors`는 제목 있는 영상 각각에 대해 `source_hash = SHA-256(title)`를 계산하고, **`embedding` 존재 AND `embedding_source_hash == source_hash`면 재호출하지 않고 스킵**한다. 신규(embedding nil) 또는 해시 불일치만 `client.embed(title)`→pack→저장.
- 배치 물질화(웹 요청 경로 재계산 없음). idempotent(재실행 시 변경 없는 행은 무호출·무변경). 결정적.
- nil/빈 제목 방어(AD-9): `title` nil이거나 blank면 임베딩 생성 안 함(스킵, embedding 미설정).

**Block If:**
- (없음 — 스텁으로 완결. 실 임베딩 호출 검증은 live 보류(키 대기).)

**Never:**
- 잡 체인 append(4.4 담당). 유사도·클러스터·콘텐츠 갭 계산(4.2~4.4). sqlite-vec 도입.
- stub 벡터를 '진짜 임베딩인 척'(STUB 로그·보류 마커 유지). 변경 없는 제목 재임베딩(과금 낭비).
- 실 Gemini HTTP를 live 외 경로에서. 키를 경계 밖에서 읽기. 화면·컨트롤러.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 신규 임베딩 | 제목 있음, embedding nil | embed 호출·BLOB·source_hash 저장 | — |
| 제목 변경 | source_hash != SHA(title) | 재생성(재호출) | — |
| 변경 없음 | embedding 존재 & 해시 일치 | 스킵(재호출 안 함) | — |
| 결정적 stub | 같은 제목 두 번 | 같은 벡터 | — |
| 차원 정합 | stub 벡터 | Config.dimensions 길이 | — |
| nil 제목 | title nil | 스킵(embedding 미설정) | AD-9 |
| 빈 제목 | title "" / 공백 | 스킵 | AD-9 |
| 다국어 | 한·일 혼재 제목 | 정상 임베딩(제목 문자열 그대로) | — |
| live 키 없음 | EMBEDDING_MODE=live, 키 nil | ConfigurationError(보류 마커) | 명확 예외 |
| 재실행 | 전부 해시 일치 | 무호출·무변경(idempotent) | — |

</intent-contract>

## Code Map

- `db/migrate/*_add_embedding_to_videos.rb` -- `videos.embedding`(binary/BLOB)·`embedding_source_hash`(string)
- `app/services/embedding/config.rb` -- `Embedding::Config`(mode·api_key·model·dimensions, ENV/credentials 경계)
- `app/services/embedding/errors.rb` -- `Embedding::Error`·`ConfigurationError`(보류 마커)
- `app/services/embedding/client.rb` -- `Embedding::Client#embed(text)` — 모드로 adapter 선택
- `app/services/embedding/adapters/stub.rb` -- 결정적 벡터·STUB 로그(진짜 아님 표식)
- `app/services/embedding/adapters/live.rb` -- 실 Gemini HTTP·타임아웃·보류(키 대기)·키 없으면 ConfigurationError
- `app/services/embedding/upsert_vectors.rb` -- `Embedding::UpsertVectors` 배치(신규·해시 변경 행만 재생성)
- `app/models/video.rb` -- `embedding`·`embedding_source_hash` 컬럼, `#embedding_vector`(unpack) 리더
- `.env.example` -- `EMBEDDING_MODE`·`GEMINI_API_KEY`·`GEMINI_EMBEDDING_MODEL`(기존)
- `test/services/embedding/*`·`test/services/embedding/upsert_vectors_test.rb` -- 재생성 조건·stub 결정성·차원·nil 방어·모드 분기

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_add_embedding_to_videos.rb` -- `add_column :videos, :embedding, :binary`(BLOB); `add_column :videos, :embedding_source_hash, :string` -- 벡터·해시 저장 -- `db:migrate && db:prepare`
- [x] `app/services/embedding/config.rb` -- `Embedding::Config`: `mode`(`EMBEDDING_MODE` 기본 stub→:stub/:live, 알수없으면 stub 폴백), `api_key`(`GEMINI_API_KEY`→credentials `dig(:gemini,:api_key)`, 복호화 실패 nil 폴백), `model`(`GEMINI_EMBEDDING_MODEL` 기본 "gemini-embedding-001"), `dimensions`(기본 768 — gemini-embedding-001 지원 차원) -- 경계 설정 -- 설정 AC
- [x] `app/services/embedding/errors.rb` -- `Embedding::Error < StandardError`, `ConfigurationError < Error`(보류 마커) -- 예외 계층
- [x] `app/services/embedding/adapters/stub.rb`·`live.rb` -- Stub: `embed(text)` → `Rails.logger.info("[Embedding] STUB …")` + 제목 SHA-256를 시드로 `Random`으로 `dimensions`개 float 생성·정규화(결정적, 같은 텍스트 같은 벡터). Live: `embed(text)` → 키 없으면 `ConfigurationError`, 있으면 Net::HTTP Gemini(`outputDimensionality: dimensions`)·타임아웃(보류 — 실호출 검증 키 대기) -- 어댑터 AC
- [x] `app/services/embedding/client.rb` -- `Embedding::Client.new(mode:, adapter:)`(테스트 주입 가능) `#embed(text)` adapter 위임. blank text 방어 -- 경계 AC
- [x] `app/services/embedding/upsert_vectors.rb` -- `Embedding::UpsertVectors.new(client:).call`: `Video.where.not(title: [nil, ""])` 각각 `source_hash = Digest::SHA256.hexdigest(video.title)`; `next if video.embedding.present? && video.embedding_source_hash == source_hash`(재호출 안 함); 아니면 `vec = @client.embed(video.title)`; `video.update!(embedding: vec.pack("f*"), embedding_source_hash: source_hash)` -- 재생성 조건 AC
- [x] `app/models/video.rb` -- `def embedding_vector; embedding && embedding.unpack("f*"); end`(nil이면 nil) -- 소비 리더(4.2)
- [x] `test/services/embedding/*` -- I/O 매트릭스(재생성 조건·stub 결정성·차원 정합·nil/빈 제목·모드 분기·live 키 없음 ConfigurationError·재실행 무호출) -- 검증

**Acceptance Criteria:**
- Given 신규 또는 제목 변경 영상, when `Embedding::UpsertVectors`를 실행하면, then `videos`의 packed-float BLOB 컬럼에 임베딩이, `embedding_source_hash`(제목 기준)에 해시가 저장된다.
- Given 임베딩이 이미 있고 제목이 그대로인 영상, when 배치를 실행하면, then `embedding_source_hash` 일치로 재호출·재생성하지 않는다(과금은 신규·변경 행에만).
- Given Gemini 임베딩, when 호출하면, then `app/services/embedding` 경계에서만 나고 `EMBEDDING_MODE`로 stub/live가 분기되며 stub은 STUB 로그로 진짜 아님을 표시한다.
- Given stub 모드, when 같은 제목을 두 번 임베딩하면, then 같은 결정적 벡터(길이 `Config.dimensions`)를 반환한다.
- Given `title`이 nil이거나 blank, when 배치를 실행하면, then 그 영상은 임베딩을 생성하지 않는다(예외 없음).
- Given 유사도 저장, when 방식을 보면, then sqlite-vec를 쓰지 않고 packed-float BLOB로 저장된다(Ruby 코사인은 4.2).

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6: (high 2, medium 4, low 0)
- defer: 0
- reject: 5: (low 5)
- addressed_findings:
  - `[high]` `[patch]` `upsert_vectors.rb` source_hash 가 제목만 키잉 → 키 도착 후 `EMBEDDING_MODE=live` 전환 시 제목 해시 일치로 가짜 stub 벡터가 영구 잔존. 해시에 출처(mode|model|dimensions) 포함 → 전환·모델·차원 변경 시 재생성.
  - `[high]` `[patch]` `upsert_vectors.rb` per-video rescue 부재 → 한 영상 embed 실패(live 키 대기·네트워크·타임아웃)가 나머지 배치를 폐기. 후보별 rescue+로그(2.5/2.6/3.4 패턴 정합).
  - `[medium]` `[patch]` `upsert_vectors.rb` `where.not(title:[nil,""])`가 공백만("   ") 제목을 못 걸러 Client#embed blank ArgumentError 로 배치 크래시. Ruby `title.blank?` 스킵.
  - `[medium]` `[patch]` `test/services/embedding/boundary_test.rb`(신규) — boundary_test 에서 embedding 제외했으나 대칭 가드 없어 GEMINI HTTP/키 경계 밖 누출 미탐지. 대칭 `Embedding::BoundaryTest` 신설(AD-1 가드 복원).
  - `[medium]` `[patch]` `adapters/live.rb` live 가 미정규화 벡터 반환(stub 은 unit) → 차원<3072 gemini 는 미정규화라 4.2 코사인이 stub·live 를 불일치 취급. live 도 L2 정규화(계약 일치).
  - `[medium]` `[patch]` `adapters/live.rb` 응답 형태·길이 미검증 → nil.pack 크래시·차원 불일치 저장 오염. Array·length==dimensions 검증 후 raise.
- rejected(noise): mode 미인식 값 stub 폴백(기존 Youtube::Config.mode 패턴 정합 — 한 경계만 바꾸면 비대칭), 제목→blank 후 stale 벡터(실 YouTube 영상은 항상 제목 보유·비현실 데이터 경로), float32 라운드트립 미세 드리프트(4.2 가 full 코사인 계산으로 흡수·Design Note 명시), stub zero-norm 가드 dead code(무해·제거는 불필요 churn), `%2^63` 시드 엔트로피(cosmetic·동작 정상).

## Design Notes

**경계는 2.2 Youtube 패턴 그대로.** `Embedding::Config`(mode/api_key/model/dimensions)·`Client`(adapter 선택·주입 가능)·`adapters/{stub,live}`·`errors`(ConfigurationError=보류 마커). stub은 제목 SHA-256을 `Random.new(seed)` 시드로 `dimensions`개 float를 만들어 정규화 — **결정적**(같은 제목→같은 벡터)이라 4.2 코사인 파이프라인이 stub에서도 동작하되, 시맨틱하진 않다(STUB 로그·보류가 '진짜 아님' 마커). live는 실 Gemini HTTP·`outputDimensionality`이되 실호출 검증은 키 대기 보류.

**제목 변경 감지 = source_hash.** `embedding_source_hash = SHA-256(title)`. 배치는 `embedding` 존재 AND 해시 일치면 스킵 — 신규·제목 변경 행만 `embed` 호출(유료 과금 최소화, AC). 제목만이 임베딩 입력이므로 해시 소스도 제목. nil/blank 제목은 스킵(AD-9).

**저장은 packed-float BLOB(AD-10).** `Array#pack("f*")`로 float32 직렬화해 `videos.embedding`(BLOB)에 저장, `Video#embedding_vector`가 `unpack("f*")`로 되돌린다. sqlite-vec 미채택 — 4.2가 BLOB를 메모리로 올려 Ruby 코사인. 차원은 Config 단일값이라 stub·live·저장이 일치. **4.2 승계:** float32 직렬화는 정규화(float64) 대비 ~1e-7 드리프트라 저장 벡터는 정확한 단위 벡터가 아니다 — 4.2 코사인은 분모(‖a‖‖b‖)를 계산하는 **완전 코사인**을 써야 하고 저장 벡터가 unit-norm이라 가정해 분모를 생략하면 안 된다. stub·live 어댑터 모두 반환 전 L2 정규화해 계약을 일치시킨다.

**재생성 키는 출처+제목.** `embedding_source_hash = SHA256(mode|model|dimensions|title)`. 제목만이 아니라 출처(mode·model·dimensions)를 포함하는 이유: 키 도착 후 `EMBEDDING_MODE=live` 전환·모델·차원 변경 시 제목이 같아도 재생성되게 해 가짜 stub 벡터가 영구 잔존하지 않게 한다(과금은 여전히 신규·변경 행에만).

**범위 경계.** 4.1은 임베딩 생성·저장까지. 유사도(4.2)·콘텐츠 갭(4.3)·클러스터(4.4)·잡 체인 append(4.4)는 후속 스토리. 이 스토리는 잡을 건드리지 않는다.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: embedding·embedding_source_hash 컬럼 추가
- `bin/rails test test/services/embedding` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "v=Video.create!(channel: Channel.first, youtube_video_id: 'demo', title: '일본인을 위한 한국어'); Embedding::UpsertVectors.new.call; v.reload; p [v.embedding_vector&.length, v.embedding_source_hash.present?]"` -- expected: `[768, true]`(stub)

## Auto Run Result

Status: done

**구현 요약** — `Embedding` 경계(2.2 Youtube 패턴 1:1: Config·Client·adapters stub/live·errors)가 제목 임베딩을 생성한다. stub은 제목 SHA-256 시드로 결정적 단위 벡터를 만들고 매 호출 STUB 로그로 '아직 진짜 아님' 표시, live(`gemini-embedding-001`)는 실 Net::HTTP·타임아웃·응답 검증·L2 정규화이되 실호출 검증은 보류(키 대기, 키 없으면 ConfigurationError). `Embedding::UpsertVectors`가 `videos.embedding`(packed-float BLOB)·`embedding_source_hash`(출처|제목 SHA-256)에 저장하고 신규·제목변경·출처변경 행만 재생성(과금 최소화). sqlite-vec 미채택(BLOB + Ruby 코사인, AD-10). 잡 체인 append 는 4.4.

**변경/신규 파일**
- `db/migrate/20260724100011_add_embedding_to_videos.rb` — embedding(BLOB)·embedding_source_hash
- `app/services/embedding/{config,errors,client,upsert_vectors}.rb`·`adapters/{stub,live}.rb`(신규)
- `app/models/video.rb` — `#embedding_vector`(unpack) 리더
- `config/application.rb` — embedding/errors.rb Zeitwerk ignore+require(youtube 패턴 미러)
- `test/services/youtube/boundary_test.rb` — embedding 경계 제외(별 HTTP 경계)
- `test/services/embedding/*`(config·stub·live·client·upsert·boundary 신규)

**리뷰 결과** — Blind + Edge Case 병렬. patch 6(출처 포함 재생성 해시·공백 제목 스킵·per-video rescue·대칭 Embedding::BoundaryTest·live L2 정규화·live 응답 검증), defer 0, reject 5. intent_gap·bad_spec 0. 부피·성격상 followup_review_recommended=true.

**검증** — Ruby 3.4.10 / Rails 8.1.3. db:migrate·db:prepare 성공. 관련 26 runs/49 assertions, 전체 249 runs/870 assertions, 0 failures(회귀 없음). 재생성 조건(신규·변경만·출처 포함)·stub 결정성·차원 정합·nil/빈/공백 제목 방어·per-video rescue·모드 분기·live 키 없음 ConfigurationError·양방향 AD-1 경계 가드 검증. `proposal.html`·`.env.example` 미변경.

**잔여 리스크(보류·후속)** — 실 Gemini 임베딩 호출·응답 대조는 live 보류(키 대기). 4.2가 저장 벡터로 완전 코사인 계산(float32 드리프트·unit-norm 비가정). 유사도·콘텐츠 갭·클러스터·잡 체인 append 는 4.2~4.4. mode 미인식 stub 폴백은 Youtube::Config 정합 유지.
