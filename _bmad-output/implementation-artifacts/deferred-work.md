# Deferred Work

작업 중 리뷰가 부수적으로 발견한, 현재 스토리 소관이 아닌 실제 이슈들을 모은다. 나중에 집중해서 다룬다.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-rails-bootstrap-multidb.md`
  summary: 큐 DB 커넥션 pool(`RAILS_MAX_THREADS`||5)이 Solid Queue 워커 동시성(processes × threads + dispatcher + recurring)보다 작을 수 있어 프로덕션 부하 시 `ConnectionTimeoutError` 여지가 있다.
  evidence: `config/database.yml`의 pool은 웹 스레드 기준 기본값인데 `config/queue.yml`의 워커 스레드/프로세스와 분리 튜닝되지 않는다. MVP(내부 2인·주1회, NFR-5 저동시성)에선 무해하나 프로덕션 스케일에서 재검토 필요.
