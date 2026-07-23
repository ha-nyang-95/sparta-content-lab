---
title: 'Story 1.1: Rails 8 부트스트랩 + SQLite 멀티DB(WAL)'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
final_revision: '1492042927910f0442c5e5e14fcba2bf52dcbc4a'
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: []
baseline_revision: '54d09d84e45eae59b2fa5b897759adbca387b82d'
---

<intent-contract>

## Intent

**Problem:** 빈 저장소(계획 문서만 존재)에 아직 Rails 앱이 없어 후속 6개 에픽이 얹힐 런타임 기반이 없다. 배치 쓰기와 웹 읽기가 SQLite에서 서로를 막지 않으려면 멀티DB + WAL 기반이 처음부터 서 있어야 한다.

**Approach:** Rails 8.x greenfield 앱을 저장소 루트에 생성하되 기존 `.gitignore`·git 히스토리를 보존하고, `config/database.yml`을 app·queue·cache 3개 SQLite 파일 분리 + WAL + `busy_timeout 5000ms`로 구성한다. Solid Queue·Solid Cache가 각자의 DB 파일에 붙게 하고 Redis 의존을 두지 않는다. `bin/rails db:prepare`와 프래그마 검증 테스트가 통과하는 것으로 완결한다.

## Boundaries & Constraints

**Always:**
- 언어는 Ruby(Rails 8.x). Python·Node 백엔드 코드를 만들지 않는다(Node는 향후 Tailwind 빌드용 툴로만 허용).
- app·queue·cache **3개** SQLite 파일이 development·test 양쪽에서 분리 정의된다(AD-12).
- 3개 DB 연결 모두 `journal_mode = WAL` + `busy_timeout = 5000`(ms)이 적용된다.
- Solid Queue는 `queue` DB에, Solid Cache는 `cache` DB에 연결된다(각 별도 파일).
- 기존 루트 `.gitignore`와 git 히스토리를 보존한다(`rails new`가 덮어쓰지 않게 `--skip-git`).
- SQLite 파일(`*.sqlite3*`)은 커밋되지 않는다(기존 `.gitignore`가 이미 처리).

**Block If:**
- `rails new`가 `.gitignore`/`.gitattributes`/`.env`/`DESIGN.md`/`_bmad*` 등 기존 파일을 덮어쓰려 하거나 계획 문서가 손실되는 경우 → HALT(blocking: `기존 파일 손실 위험`).
- Rails 8.x 또는 Ruby 3.4 툴체인이 동작하지 않는 경우 → HALT(blocking: `툴체인 부재`).

**Never:**
- Redis·Sidekiq·Postgres 도입(솔리드 스택 + SQLite만).
- Action Cable / Solid Cable 도입(웹소켓 불요 — 3 DB 유지, cable DB 만들지 않음).
- Tailwind·인증·scoring.yml·앱 셸 구현(각각 Story 1.3·1.2·1.5·1.4 소관 — 이 스토리에서 건드리지 않는다).
- 스코어링/수집/화면 등 후속 에픽 코드.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 멀티DB 준비 | 새 앱, 마이그레이션 없음 | `bin/rails db:prepare`가 app·queue·cache 3개 파일을 생성하고 각 스키마를 로드 | 실패 시 비제로 종료 |
| WAL 프래그마 | primary 연결 | `PRAGMA journal_mode` → `wal` | 아니면 테스트 실패 |
| busy_timeout | 각 DB 연결 | `PRAGMA busy_timeout` → `5000` | 아니면 테스트 실패 |
| 큐/캐시 격리 | 부팅된 앱 | Solid Queue 연결 DB 파일명에 `queue`, Solid Cache에 `cache` 포함 | 아니면 테스트 실패 |
| Redis 부재 | Gemfile·설정 | `redis` 젬·설정 참조가 없음(grep) | 발견 시 실패 |

</intent-contract>

## Code Map

- `Gemfile` -- Rails 8.x·sqlite3·solid_queue·solid_cache 의존(생성물). redis 없어야 함
- `config/database.yml` -- app/queue/cache 3파일 + WAL·busy_timeout 프래그마의 단일 소재지
- `config/cache.yml` -- Solid Cache가 `cache` DB에 붙는 설정
- `config/environments/*.rb` -- Solid Queue 커넥션(`config.solid_queue.connects_to`)·큐 어댑터
- `db/queue_schema.rb`·`db/cache_schema.rb` -- 큐/캐시 DB 스키마(생성물)
- `test/database_setup_test.rb` -- WAL·busy_timeout·큐/캐시 격리 검증 테스트(신규)

## Tasks & Acceptance

**Execution:**
- [x] `.` -- `rbenv` 셸에서 `rails new . -d sqlite3 --skip-action-cable --skip-git --force` 실행 -- Rails 8 앱을 루트에 생성하되 기존 `.gitignore`·git 보존, cable 제외로 3 DB 유지. 생성 직후 `git status`로 기존 계획 문서·`.gitignore`·`.env` 무손실 확인
- [x] `config/database.yml` -- development·test·production 각각 primary/cache/queue 3개 sqlite 파일 정의 + `default`에 `timeout: 5000`과 `pragmas: { journal_mode: WAL, busy_timeout: 5000, synchronous: NORMAL, foreign_keys: true }` 적용(Design Notes 골든 예시) -- AD-12/WAL/busy_timeout AC 충족
- [x] `config/environments/development.rb`·`test.rb`·`production.rb` -- `config.active_job.queue_adapter = :solid_queue`, `config.solid_queue.connects_to = { database: { writing: :queue } }` -- Solid Queue가 `queue` DB에 붙음
- [x] `config/cache.yml` -- 각 환경 `database: cache` 지정 -- Solid Cache가 `cache` DB에 붙음
- [x] `test/database_setup_test.rb` -- I/O 매트릭스 검증 테스트 작성(WAL·busy_timeout·큐/캐시 DB 파일명·Redis 부재) -- 자기 검증
- [x] `Gemfile` -- redis 젬 부재 확인, `bundle install` 통과 -- 솔리드 스택만

**Acceptance Criteria:**
- Given 빈 저장소, when `rails new`를 실행하면, then 언어는 Ruby이고 기존 `.gitignore`·`.env`·`DESIGN.md`·`_bmad*`·`docs`·`Planning`이 그대로 남는다.
- Given 생성된 앱, when `config/database.yml`을 보면, then development·test·production 각각에 app·queue·cache 3개 SQLite 파일이 분리 정의되고 WAL·`busy_timeout 5000`이 기본 적용된다.
- Given 부팅된 앱, when Solid Queue·Solid Cache 연결을 조회하면, then 각각 `queue`·`cache` DB 파일에 연결된다.
- Given Gemfile·설정, when redis를 grep하면, then 참조가 없다.
- Given 새 앱, when `bin/rails db:prepare`를 실행하면, then 3개 DB가 생성·스키마 로드되고 종료 코드 0이다.

## Spec Change Log

_(bad_spec 루프백 없음 — 비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 3: (high 0, medium 2, low 1)
- defer: 1: (low 1)
- reject: 5: (low 5)
- addressed_findings:
  - `[medium]` `[patch]` `config/database.yml` busy_timeout 충돌 — pragma가 adapter `timeout:` 옵션의 GVL-friendly busy 핸들러를 나중에 덮어씀. 중복 `timeout: 5000` 제거, pragma가 단일 소유(NFR-2 busy_timeout 5000ms). 주석으로 재발 방지.
  - `[medium]` `[patch]` `test/database_setup_test.rb` — 테스트가 test 환경만 검증(dev/prod 3-DB 격리 미검증, 복붙 드리프트 위험). development/test/production 각 primary·cache·queue 존재 + 경로 상호 distinctness 단언 추가.
  - `[low]` `[patch]` `test/database_setup_test.rb` "no redis" 스캔 강화 — Gemfile.lock(전이 의존) 포함, `scrub`로 바이너리 config 크래시 방어, 인라인 주석 제거로 오탐 방지.
- deferred: 큐 DB pool(`RAILS_MAX_THREADS`||5) vs Solid Queue 워커 동시성 — 프로덕션 스케일 튜닝(MVP 무관).
- rejected(noise/stock): synchronous:NORMAL(Rails 기본·WAL+NORMAL 권장·일일백업 AD-17), connects_to per-env 3중복(정상 관용구), Solid Cache connects_to 비대칭(젬 설계 고유), cache.yml namespace(stock 생성물), migrations_paths 팬텀 디렉터리(stock Solid 패턴·db:prepare 정상).

## Design Notes

`config/database.yml` 골든 구조(환경마다 3 DB, 프래그마는 `default` 앵커에 1회):

```yaml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  # adapter timeout: 옵션은 두지 않는다 — 아래 busy_timeout pragma와 충돌(pragma가 나중에 이김).
  pragmas:
    journal_mode: WAL
    busy_timeout: 5000
    synchronous: NORMAL
    foreign_keys: true

development:
  primary:
    <<: *default
    database: storage/development.sqlite3
  cache:
    <<: *default
    database: storage/development_cache.sqlite3
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    database: storage/development_queue.sqlite3
    migrations_paths: db/queue_migrate
# test: 동일 구조로 storage/test*.sqlite3 3파일
# production: storage/production*.sqlite3 3파일(기존 생성물 기반, cable 항목 제거)
```

테스트 검증 예(Minitest, 핵심만):

```ruby
# journal_mode·busy_timeout
conn = ActiveRecord::Base.connection
assert_equal "wal", conn.execute("PRAGMA journal_mode").first["journal_mode"].downcase
assert_equal 5000, conn.execute("PRAGMA busy_timeout").first["timeout"]
# 큐/캐시 격리
assert_includes SolidQueue::Job.connection.pool.db_config.database, "queue"
assert_includes SolidCache::Entry.connection.pool.db_config.database, "cache"
```

주의 — Rails 8 기본 `database.yml`은 production만 멀티DB이고 cable을 포함할 수 있다. development·test에도 3 DB를 명시하고 cable 항목은 제거한다. `db/cable_schema.rb`가 생성되면 삭제한다.

## Verification

**Commands:**
- `ruby -v` -- expected: `3.4.x`
- `bin/rails -v` -- expected: `Rails 8.x`
- `bin/rails db:prepare` -- expected: 종료 0, `storage/`에 app/queue/cache 3개 `*.sqlite3` 생성
- `bin/rails test test/database_setup_test.rb` -- expected: 전부 통과
- `grep -ri "redis" Gemfile config/ | grep -v "#"` -- expected: 매치 없음
- `git status --porcelain -- .gitignore .env DESIGN.md` -- expected: 변경 없음(무손실)

## Auto Run Result

Status: done

**구현 요약** — Rails 8.1.3 greenfield 앱을 저장소 루트에 생성(`rails new . -d sqlite3 --skip-action-cable --skip-git --force`)하고, `config/database.yml`을 app·queue·cache 3개 SQLite 파일 분리 + WAL·busy_timeout 5000ms(pragma 단일 소유)로 구성. Solid Queue→queue DB, Solid Cache→cache DB, Action/Solid Cable·Redis 없음. 기존 `.gitignore`·`.env`·`DESIGN.md`·계획 문서 전부 보존.

**변경 파일(주요)**
- `config/database.yml` — dev·test·production 각 3-DB 분리 + WAL/busy_timeout/synchronous/foreign_keys pragma(default 앵커 1회)
- `config/cache.yml` — Solid Cache가 `cache` DB에 바인딩(`database: cache`)
- `config/environments/{development,test,production}.rb` — `solid_cache_store`·`solid_queue` 어댑터·`connects_to writing: :queue`
- `test/database_setup_test.rb` — WAL·busy_timeout(3연결)·큐/캐시 격리·다환경 3-DB distinctness·no-redis(Gemfile+lock+config, scrub·주석제거) 9 tests/37 assertions
- 그 외 `rails new` stock 스캐폴드(app/·bin/·lib/·public/·Gemfile 등)

**리뷰 결과** — Blind Hunter + Edge Case Hunter 병렬. patch 3(medium 2·low 1) 적용, defer 1(큐 pool 튜닝→`deferred-work.md`), reject 5(stock/noise). intent_gap·bad_spec 0(루프백 없음).

**검증** — Ruby 3.4.10 / Rails 8.1.3. `bin/rails db:prepare`(dev·test) 종료 0, `storage/`에 6개 sqlite 생성. `bin/rails test test/database_setup_test.rb` → 9 runs, 37 assertions, 0 failures. redis grep 매치 없음. `.gitignore`/`.env`/`DESIGN.md` 무변경.

**잔여 리스크** — busy_timeout는 native pragma(GVL 보유형)로 동작하나 아키텍처의 단일 라이터·저동시성(NFR-5)으로 완화됨. 큐 DB pool 튜닝은 프로덕션 스케일 시 재검토(deferred).
