---
title: 'Story 2.5: DailyCollectionJob 체인 골격 + 관측성 + 백업'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
warnings: []
baseline_revision: '025094352193d112cdebe42cc95995066e676e5b'
final_revision: 'ad47e69a62df3d921f65f46c25fa28e8467409d8'
---

<intent-contract>

## Intent

**Problem:** 2.2~2.4의 수집·스냅샷 서비스가 있으나 이를 매일 자동으로 도는 잡·스케줄·관측·백업이 없다. 컴퓨터가 꺼져도 수집이 끊기면 안 된다.

**Approach:** `DailyCollectionJob`(Solid Queue recurring, 하루 1회)이 스테이지 체인을 **조립만** 하고 로직은 서비스에 위임한다(AD-11) — 채널별 열거(2.3) → 스냅샷 저장(2.4). 하나의 `QuotaLedger`+`Client`를 전 채널에 공유해 런 전체 쿼터를 회계한다. `JobRun`에 시작·성공·실패·재시도·쿼터 사용량을 기록한다(AD-13). `app.sqlite3` 일일 백업 유틸·rake·절차를 둔다(AD-17, queue/cache 제외). 수집은 2.2 경계(stub)로 도므로 스텁에 대고 테스트하고 실 fetch는 2.2 Live 보류(키 대기).

## Boundaries & Constraints

**Always:**
- `DailyCollectionJob < ApplicationJob` — `perform`은 체인 조립만. 채널 열거는 `Youtube::FetchChannelVideos`(2.3), 스냅샷은 `Snapshot::RecordDailyStats`(2.4)에 위임. 로직을 잡에 복제하지 않는다(AD-11).
- 하나의 `Youtube::QuotaLedger`를 만들어 `Youtube::Client.new(ledger:)`로 전 채널에 공유 — 런 전체 공유 풀+search 버킷을 누적 회계.
- 대상 채널은 `Channel.not_excluded.where.not(youtube_channel_id: nil)`. **채널별 처리**로 한 채널 실패가 앞 채널 결과를 버리지 않는다(per-channel rescue, 부분 진행 보존).
- 관측성 — `JobRun`(job_name·status(running/succeeded/failed)·started_at·finished_at·error·quota_used·retries) primary DB에 기록. 잡이 실행마다 start!→succeed!/fail!.
- 실패는 지수 백오프 재시도(`retry_on`), **재시도는 일1회 갱신 상한과 별개**(recurring 스케줄은 하루 1회, 재시도는 예외 처리).
- 스케줄·잡 상태는 **서버 재시작 후에도 지속**(Solid Queue가 queue DB에 저장). recurring은 `config/recurring.yml`에 정의.
- 백업 — `Backup::AppDatabase`가 primary(`app`/스냅샷 원천) DB만 `VACUUM INTO`로 일관 스냅샷 백업(queue/cache 제외). rake 태스크 + 운영 절차 문서화.

**Block If:**
- (없음 — 스텁으로 완결. 실 수집은 2.2 Live 보류.)

**Never:**
- 실 YouTube HTTP(2.2 Live 보류·stub 모드로 테스트). 잡에 API 호출·파싱 로직 복제.
- 기준선·성과 배수·에버그린 스테이지 로직(Epic 3) — 체인에 **자리만**(이후 append), 지금 계산 안 함.
- 화면·컨트롤러. queue/cache DB 백업.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 정상 수집 | stub 모드, 시드 채널 | 채널별 FetchChannelVideos → RecordDailyStats, JobRun succeeded·quota_used 기록 | — |
| 채널 실패 | 한 채널 열거가 raise | 그 채널 로그·스킵, 나머지 채널·스냅샷 계속, JobRun succeeded(부분) | — |
| 체계적 실패 | 스냅샷 단계 raise 등 | JobRun failed·error 기록 후 재raise(재시도) | retry_on 백오프 |
| 재시작 지속 | 스케줄 등록 후 재시작 | recurring 스케줄·잡 상태 유지(DB) | — |
| 백업 | Backup::AppDatabase.call | primary DB만 VACUUM INTO 백업 파일 생성 | queue/cache 제외 |

## Code Map

- `db/migrate/*_create_job_runs.rb` + `app/models/job_run.rb` -- 관측 레코드(primary)
- `app/jobs/daily_collection_job.rb` -- 체인 조립·JobRun 기록·쿼터 공유·채널별 rescue
- `config/recurring.yml` -- DailyCollectionJob 하루 1회 recurring
- `app/services/backup/app_database.rb` + `lib/tasks/backup.rake` -- app DB 백업(VACUUM INTO)·rake·절차
- `test/models/job_run_test.rb`·`test/jobs/daily_collection_job_test.rb`·`test/services/backup/*` -- 검증

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_create_job_runs.rb` + `app/models/job_run.rb` -- job_runs(job_name·status·started_at·finished_at(null)·error(text null)·quota_used(int null)·retries(default 0)) primary. status inclusion(running/succeeded/failed), `start!`/`succeed!`/`fail!`. `bin/rails db:migrate` -- 관측 AC
- [x] `app/jobs/daily_collection_job.rb` -- perform: JobRun.start! → ledger=QuotaLedger.new, client=Client.new(ledger:) → Channel.not_excluded(youtube_channel_id 있음) 각각 FetchChannelVideos.new(client:).call(채널별 rescue) → Snapshot::RecordDailyStats.call → succeed!(quota_used: ledger 합). 체계적 실패는 fail!+raise. `retry_on` 백오프 -- 체인·쿼터·관측 AC
- [x] `config/recurring.yml` -- production에 daily_collection: DailyCollectionJob, 하루 1회 스케줄(저트래픽 시각) -- 스케줄 지속 AC
- [x] `app/services/backup/app_database.rb` + `lib/tasks/backup.rake` -- `call(dir:)`: primary DB를 `VACUUM INTO '<dir>/app-<timestamp>.sqlite3'`로 백업(queue/cache 제외). rake `backup:app_db`. 상단 주석에 일일 백업 절차(cron 예시) -- 백업 AC
- [x] `test/models/job_run_test.rb`·`test/jobs/daily_collection_job_test.rb`·`test/services/backup/app_database_test.rb` -- JobRun 상태전이·잡 정상(JobRun succeeded·스냅샷·quota_used)·채널 실패 회복·백업(VACUUM INTO 파일 생성, use_transactional_tests=false) -- 검증

**Acceptance Criteria:**
- Given Solid Queue recurring 스케줄, when `DailyCollectionJob`이 하루 1회 실행되면, then 잡은 스테이지 체인 조립만 하고(channels→playlistItems→videos→스냅샷 저장) 로직은 서비스에 위임한다.
- Given 서버 재시작, when 스케줄을 확인하면, then 스케줄·잡 상태가 지속된다(DB 저장).
- Given 실행, when 이력을 보면, then 시작·성공·실패·재시도·쿼터 사용량이 `job_runs`에 기록된다.
- Given 실패, when 재시도하면, then 지수 백오프로 재시도되고 재시도는 일1회 갱신 상한에 포함되지 않는다.
- Given `app.sqlite3`(스냅샷 원천), when 백업하면, then 일일 백업 절차가 정의되고 queue/cache DB는 제외된다.

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 7: (high 1, medium 2, low 4)
- defer: 0
- reject: 1: (low 1)
- addressed_findings:
  - `[high]` `[patch]` `daily_collection_job.rb` `retry_on Youtube::RateLimited`가 죽은 config — per-channel rescue가 RateLimited를 삼켜 잡 재시도에 도달 못 함. YouTube rate/quota는 경계(2.2 백오프)·채널별에서 처리가 맞고, 잡 재시도는 일시 인프라 오류(`ActiveRecord::Deadlocked`)로 타깃 변경.
  - `[medium]` `[patch]` `daily_collection_job.rb`/`job_run.rb` 전 채널 실패·부분 실패가 succeeded로 위장(정직성 위반, 관측 불가). channels_processed/failed 추적(신규 마이그레이션+인덱스), 전채널실패→failed, 부분실패 실패수 기록.
  - `[medium]` `[patch]` `job_run.rb`/job `retries` 컬럼 미기록(AC 미충족)·프로세스 중단 시 running 고아. `start!`가 `executions-1` 기록, `reap_stale!`(오래된 running→failed)를 잡 시작 시 호출.
  - `[low]` `[patch]` `daily_collection_job.rb` `quota_used`가 shared units + search calls를 무의미 합산 → shared만 기록(일일 수집은 search 미사용).
  - `[low]` `[patch]` `backup/app_database.rb` VACUUM INTO 대상 파일 동초 충돌 → 랜덤 접미사 uniquifier.
  - `[low]` `[patch]` `backup/app_database.rb` 백업 무한 증가 → keep 개만 남기는 rotation(prune).
  - `[low]` `[patch]` `daily_collection_job.rb` `JobRun.start!`가 ledger/client 구성 전 → 구성 실패 시 running 고아. client 구성을 begin 내부로.
- rejected(noise): `daily_collection`이 production 섹션만(Rails recurring 관용구·의도적, dev는 perform_now로 테스트).

## Design Notes

**체인 조립만.** 잡은 순서·오케스트레이션만 담고, 채널 열거는 `FetchChannelVideos`(2.3, 이미 channels→playlistItems→videos 체인·트랜잭션), 스냅샷은 `RecordDailyStats`(2.4)에 위임한다. Epic 3 스테이지(기준선/성과배수/에버그린)는 이후 이 체인에 append — 지금은 스냅샷 뒤에 자리(주석)만.

**쿼터 공유·관측.** 하나의 `QuotaLedger`를 만들어 `Client.new(ledger:)`로 전 채널이 공유 → 런 전체 units·search 콜 누적. 끝나면 `ledger.spent(:shared)+spent(:search)`를 `JobRun.quota_used`에 기록. 채널별 `rescue`로 부분 진행 보존(2.4 recorder·2.3 채널 트랜잭션과 정합).

**재시도.** `retry_on Youtube::RateLimited`(또는 일시 오류) 지수 백오프. Solid Queue 재시도는 별도 실행이라 recurring "하루 1회"와 무관(상한 포함 안 함, AC).

**백업.** SQLite `VACUUM INTO`는 일관 스냅샷을 새 파일로 만든다(원본 미변경, WAL 안전). primary 연결에서만 실행 → queue/cache 자동 제외. rake `backup:app_db`가 호출, 상단 주석/절차에 cron 등록 예시. VACUUM은 트랜잭션 밖 필요 → 백업 테스트는 `use_transactional_tests = false`(백업은 읽기라 DB 미오염).

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: job_runs(primary), 종료 0
- `bin/rails test test/models/job_run_test.rb test/jobs test/services/backup` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "DailyCollectionJob.perform_now; p JobRun.last.slice(:status, :quota_used)"` -- expected: succeeded·quota_used 기록(stub)
- `grep -A3 daily_collection config/recurring.yml` -- expected: DailyCollectionJob 하루 1회

## Auto Run Result

Status: done

**구현 요약** — `DailyCollectionJob`(Solid Queue recurring 하루 1회)이 체인을 조립만(AD-11) — 채널별 `FetchChannelVideos`(2.3) → `Snapshot::RecordDailyStats`(2.4). 하나의 `QuotaLedger`+`Client` 공유로 런 전체 쿼터 회계. `JobRun`(status·started/finished·error·quota_used·retries·channels_processed/failed) 관측(AD-13), 전채널실패→failed·부분실패 기록·중단 running 회수. `Backup::AppDatabase`(VACUUM INTO primary만·uniquifier·rotation) + rake `backup:app_db`(AD-17). recurring.yml 등록. 실 fetch는 2.2 Live 보류.

**변경/신규 파일** — `app/jobs/daily_collection_job.rb`·`app/models/job_run.rb`·`app/services/backup/app_database.rb`·`lib/tasks/backup.rake`(신규), `db/migrate/*job_runs*`·`*collection_metrics*`, `config/recurring.yml`, `test/jobs/*`·`test/models/job_run_test.rb`·`test/services/backup/*`.

**리뷰 결과** — Blind + Edge Case 병렬. AD-11 조립 순수성·백업 격리·쿼터 공유 확인. patch 7(high 1: retry_on 죽은 config 수정; medium 2: 정직성 관측·retries/reaper; low 4), reject 1(production-only recurring). intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 145 runs, 633 assertions, 0 failures(회귀 없음). 잡 succeeded·quota 12·스냅샷, 채널별 회복·실패수 기록, 전채널실패→failed, reaper, retry_on Deadlocked(RateLimited 아님), 백업 primary만·queue 테이블 제외·rotation(keep). job_runs primary만. `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — recurring 스케줄은 production만(dev는 perform_now). 실 수집·실데이터는 2.2 Live 보류(키 대기). 대규모 롤업은 SQL 씨닝(2.4 deferred). 백업 스케줄러 실등록은 운영 절차(cron).
