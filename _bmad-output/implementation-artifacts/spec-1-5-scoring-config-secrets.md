---
title: 'Story 1.5: config/scoring.yml 튜닝값 자리 + 시크릿 격리'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: []
baseline_revision: 'e23e47b47d88a391e4517384f14584e23e439f88'
final_revision: '7791faaa650a004f4fa986ccae731cea551ddf8f'
---

<intent-contract>

## Intent

**Problem:** 스코어링 튜닝값(기준선 N·τ·가중치·임계 등)이 미확정인데, 이를 코드 상수로 흩어 두면 본개발 실측 튜닝 때 여러 파일을 고쳐야 하고 회귀가 샌다(AD-4). 또 API 키가 리포·코드에 하드코딩될 위험이 있다.

**Approach:** AD-4 튜닝값을 `config/scoring.yml` **단일 설정**에 잠정 기본(PRD §13 [ASSUMPTION])으로 두고, 얇은 로더(`Scoring::Config`)로만 읽는다. 누락 키는 raise 시켜 상수 하드코딩·오타 회귀를 테스트가 잡게 한다. API 키(YouTube·Gemini)는 ENV(`.env`는 dotenv-rails로 로드)로만, 서비스 경계에서만 읽고, 리포·코드에 키 하드코딩이 없음을 grep 테스트로 가드한다.

## Boundaries & Constraints

**Always:**
- 모든 AD-4 튜닝 키가 `config/scoring.yml`에 존재한다 — 기준선 N·신뢰도 표본 하한·유사도 τ·기회 점수 가중치(4입력)와 정규화 매핑·에버그린 나이/배수 임계·조회수 하한(고정값+k)·구독자 규모 임계(밴드)·극단배수(25)·배수 프리셋·위젯별 콜드스타트 스냅샷 수·is_short duration 임계.
- 튜닝값은 **오직** `Scoring::Config`(→ `config/scoring.yml`)로 읽는다. 로더는 얇고, 없는 키 요청 시 `KeyError` raise(하드코딩·오타 회귀를 테스트가 포착).
- 값은 잠정 기본이며 각 항목에 "본개발 실측 튜닝" 취지 주석을 단다. 값 자체가 계약이 아니라 **자리(키)와 단일 소재지**가 계약이다.
- API 키(YouTube·Gemini)는 ENV로만 읽는다(`.env`는 dotenv-rails가 dev/test에서 로드, `.env.example`이 템플릿). 리포·코드에 키 값 하드코딩 없음.
- API 키 ENV 참조는 서비스 경계(`app/services/**`)에서만(현재 서비스 없음 → 규칙은 전방 가드).

**Block If:**
- (없음 — 설정/인프라, 외부 호출 없음.)

**Never:**
- 스코어링 계산 로직 구현(Epic 3). 이 스토리는 값의 자리·로더·시크릿 격리까지.
- 튜닝값을 코드 상수로 중복 정의. 키를 코드에 하드코딩.
- API 키를 리포·코드·`.env.example`에 실제 값으로 넣기(플레이스홀더/빈 값만).
- 실제 YouTube/Gemini 호출(Epic 2·4, 키 대기).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 튜닝값 읽기 | `Scoring::Config.fetch(:baseline, :sample_size_n)` | `config/scoring.yml` 값 반환 | 없는 키 → `KeyError` |
| 전 키 존재 | 로더로 AD-4 키 전부 조회 | 각각 non-nil | 누락 시 테스트 실패 |
| 단일 소재지 | 로더 경로 | `config/scoring.yml` 하나만 참조 | — |
| 키 하드코딩 | 리포 grep | Google 키 패턴·키 리터럴 없음 | 발견 시 실패 |
| 키 읽기 위치 | 코드 grep | `YOUTUBE_API_KEY`/`GEMINI_API_KEY` 참조가 app/services 밖에 없음 | 발견 시 실패 |

</intent-contract>

## Code Map

- `config/scoring.yml` -- AD-4 튜닝값 단일 소재지(잠정 기본 + 주석)
- `app/services/scoring/config.rb` -- 얇은 로더(`Scoring::Config`): memoized, `fetch`(누락 시 KeyError)
- `Gemfile` -- `dotenv-rails`(dev/test)로 `.env` 로드
- `test/services/scoring/config_test.rb` -- 전 AD-4 키 존재·단일 소재지·KeyError
- `test/secrets_isolation_test.rb` -- 키 하드코딩 부재·서비스 경계 밖 키 참조 부재 grep 가드

## Tasks & Acceptance

**Execution:**
- [x] `config/scoring.yml` -- AD-4 키 전부를 잠정 기본으로 정의(Design Notes 값), 각 그룹에 "본개발 실측 튜닝" 주석 -- 튜닝값 자리 AC
- [x] `app/services/scoring/config.rb` -- `Scoring::Config` 얇은 로더: `config/scoring.yml`을 1회 로드·deep-symbolize·memoize, `fetch(*keys)`(누락 시 `KeyError`), `all` 반환. `config_for` 또는 `YAML` 중 택1(얇게) -- 단일 소재지·회귀 포착 AC
- [x] `Gemfile` -- `gem "dotenv-rails"`를 dev/test 그룹에 추가, `bundle install` -- `.env` 로드로 API 키 ENV 격리 AC
- [x] `test/services/scoring/config_test.rb` -- (1) AD-4 키 전부 non-nil로 조회, (2) 로더가 `config/scoring.yml` 경로를 읽음, (3) 없는 키 `fetch` → `KeyError` -- 튜닝 회귀 가드
- [x] `test/secrets_isolation_test.rb` -- (1) 리포에 Google API 키 패턴/키 리터럴 하드코딩 없음(grep), (2) `YOUTUBE_API_KEY`/`GEMINI_API_KEY` 참조가 `app/services` 밖에 없음(전방 가드), (3) `.env`는 미추적·ignore -- 시크릿 격리 AC

**Acceptance Criteria:**
- Given 스코어링·표시 코드가 튜닝값을 필요로 할 때, when `config/scoring.yml`을 참조하면, then AD-4 키 자리가 전부 존재한다.
- Given 값은 잠정 기본(PRD §13), when 코드가 값을 읽으면, then 오직 이 파일에서만 읽고 상수 하드코딩이 없다(없는 키는 KeyError로 테스트가 회귀를 잡는다).
- Given API 키(YouTube·Gemini), when 코드가 키를 읽으면, then Rails credentials 또는 ENV로만·서비스 경계에서만 읽는다.
- Given 리포·코드, when 키를 grep하면, then 하드코딩된 키가 없다.

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 6: (high 0, medium 3, low 3)
- defer: 1: (low 1)
- reject: 3: (low 3)
- addressed_findings:
  - `[medium]` `[patch]` `test/secrets_isolation_test.rb` 시크릿 가드가 `git ls-files`(추적 파일만) 스캔 → 미추적 파일(자기 자신 포함) 맹점, 커밋 전 유출 false-pass(리뷰어 실증). 파일시스템 소스 스캔으로 전환(.env·빌드·_bmad-output·config 암호화키·테스트 자신 제외). 심은 키 포착 실증 검증.
  - `[medium]` `[patch]` `test/secrets_isolation_test.rb` 전방 가드가 `app/**`만 → `lib/`·`config/` 유출 미포착(AD-1 위반 escape). `{app,lib,config}/**/*.rb` 스캔, app/services 제외.
  - `[medium]` `[patch]` `app/services/scoring/config.rb` 로더가 memoize 해시 라이브 참조 반환 → Epic 3 소비자가 단일 원천 mutate 가능. deep-freeze(FrozenError로 방어, 실증).
  - `[low]` `[patch]` `config.rb` `fetch()` 인자 0개 시 전체 반환 → ArgumentError. 빈/절단 YAML `|| {}` 방어(NoMethodError·memo 무효화 방지).
  - `[low]` `[patch]` `config_test.rb` opportunity_score.normalization 미검증 → Hash 자리 단언 추가("전 AD-4 키 non-nil" 주장 정합).
  - `[low]` `[patch]` `secrets_isolation_test.rb` AIza-only → PEM `-----BEGIN … PRIVATE KEY-----` 블록도 탐지.
- deferred: test 환경에서 YOUTUBE_API_MODE/EMBEDDING_MODE stub 강제(.env 실키가 test ENV에 로드됨 — live 경로 우발 호출 방지). Epic 2·4의 모드 소비 코드와 함께 처리(deferred-work).
- rejected(noise/필요): `_bmad-output`·테스트 자신 스캔 제외(AIza regex 리터럴 자기매칭 방지에 필수), `@all ||=` 스레드안전(idempotent·무해), 할당 가드 var명 확대(YouTube/Gemini 2키가 스코프 핵심).

## Design Notes

**`config/scoring.yml` 잠정 기본(PRD §13 [ASSUMPTION] 기반 — 값은 본개발 실측 튜닝 대상, 자리·단일 소재지가 계약).** 예시 구조:

```yaml
# 스코어링 튜닝값 단일 소재지 (AD-4). 값은 잠정 기본(PRD §13 ASSUMPTION) — 본개발 실측으로 확정한다.
# 코드는 이 파일만 Scoring::Config 로 읽는다. 상수 하드코딩 금지.
baseline:
  sample_size_n: 25          # 채널·유형별 최근 N개 공개 영상(중앙값 표본). PRD 기본 20~30
  min_sample_for_confidence: 10  # 유형별 최근 공개 영상 이 수 미만이면 low_confidence
performance:
  view_floor_fixed: 300      # 조회수 하한 = max(고정, k×기준선). 자사 공개 200~4,100 정당 대박 보호
  view_floor_k: 0.1
  extreme_multiple: 25       # >25x "검증 요망" 플래그
  multiple_presets: [2, 3, 5, 10, 25]  # 필터 프리셋
evergreen:
  min_age_days: 180          # 나이 임계 AND 배수 임계 동시 충족
  min_multiple: 2
similarity:
  tau: 0.8                   # 코사인 임계(FR-17, 주제 묶기 재사용). 고정 0.8 맹신 금지
opportunity_score:
  weights:                   # 4입력 가중합(투명). 초기 등가, 피드백으로 조정
    performance_signal: 0.25
    competitor_commonality: 0.25
    content_gap: 0.25
    recency: 0.25
  normalization: {}          # 각 입력 [0,1] 정규화 매핑 자리(본개발 확정)
subscriber_bands: [10000, 100000, 500000]  # <1만 / 1만~10만 / 10만~50만 / 50만+
cold_start_snapshots:        # 위젯별 "수집 중"→표시 전환 스냅샷 수
  sparkline: 7
  vpd: 2
  evergreen_validation: 14
  subscriber_delta: 7
is_short:
  max_duration_seconds: 180  # duration 휴리스틱 임계(ClassifyShort 1회 판정). 본개발 확정
```

**로더는 얇게.** `Scoring::Config.fetch(:performance, :extreme_multiple)` 식으로 nested 접근, 없는 키는 `KeyError`(하드코딩·오타 회귀를 테스트가 잡음). `config_for(:scoring)`을 쓰면 YAML을 `shared:` 아래 두거나, 단순 `YAML.safe_load` + deep-symbolize도 무방(값이 환경 불변 방법론 상수라 env 분기 불필요). 택1하되 단일 경로만 읽는다.

**시크릿.** `.env.example`이 이미 `YOUTUBE_API_KEY`/`GEMINI_API_KEY`/모드 스위치를 담는다. `dotenv-rails`(dev/test)로 `.env`를 로드해 ENV로 격리. `.env`는 이미 gitignore·미추적. 프로덕션은 실제 ENV/credentials로 주입. grep 가드로 하드코딩·경계 밖 참조를 막는다.

## Verification

**Commands:**
- `bin/rails runner "require 'scoring/config' rescue nil; p Scoring::Config.fetch(:performance, :extreme_multiple)"` -- expected: `25`
- `bin/rails test test/services/scoring/config_test.rb` -- expected: 전부 통과
- `bin/rails test test/secrets_isolation_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rInE "AIza[0-9A-Za-z_-]{20,}" . --exclude-dir=.git` -- expected: 매치 없음(Google 키 패턴)
- `git check-ignore .env` -- expected: ignored

## Auto Run Result

Status: done

**구현 요약** — AD-4 스코어링 튜닝값을 `config/scoring.yml` 단일 소재지에 잠정 기본(PRD §13 ASSUMPTION)으로 두고, 얇은 로더 `Scoring::Config`(deep-symbolize·deep-freeze·memoize, nested `fetch`는 누락 시 KeyError·빈 인자 ArgumentError)로만 읽는다. API 키는 dotenv-rails(dev/test)가 `.env`로 로드해 ENV로 격리하고, 하드코딩·경계 밖 참조를 소스 스캔 테스트로 가드한다.

**변경 파일**
- `config/scoring.yml` — baseline/performance/evergreen/similarity/opportunity_score/subscriber_bands/cold_start_snapshots/is_short (전 AD-4 키, "본개발 튜닝" 주석)
- `app/services/scoring/config.rb` — `Scoring::Config` 얇은 로더(frozen 단일 원천)
- `Gemfile` — `dotenv-rails`(dev/test)
- `test/services/scoring/config_test.rb`(3 tests) — 전 AD-4 키·KeyError·단일 소재지
- `test/secrets_isolation_test.rb`(4 tests) — 하드코딩 키/PEM·경계 밖 참조·.env ignore

**리뷰 결과** — Blind + Edge Case 병렬. AD-4 키 완전성·로더 mid-path·단일 소재지·.env.example 클린 확인. patch 6(가드 파일시스템 스캔·lib/config 확대·deep-freeze·robustness), defer 1(test stub 모드), reject 3(regex 자기매칭 제외 필수 등). intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 44 runs, 347 assertions, 0 failures(1.1~1.4 회귀 없음). 로더 25/180/밴드 해결, frozen mutate→FrozenError, fetch()→ArgumentError, 미추적 파일 심은 키 포착 실증, .env ignore·.env.example 빈 값.

**잔여 리스크** — 값은 잠정(본개발 실측 확정). test 환경 stub 모드 강제는 Epic 2·4 모드 코드와 함께(deferred). opportunity_score.normalization 은 빈 자리(Epic 5 확정).
