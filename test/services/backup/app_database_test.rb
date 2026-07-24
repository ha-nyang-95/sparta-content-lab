# Backup::AppDatabase — VACUUM INTO 로 유효한 SQLite 백업 생성·queue 전용 테이블 제외 검증
require "test_helper"

class Backup::AppDatabaseTest < ActiveSupport::TestCase
  # VACUUM INTO 는 트랜잭션 안에서 실행할 수 없다. 백업은 읽기라 DB를 오염시키지 않는다.
  self.use_transactional_tests = false

  def setup
    @dir = Rails.root.join("tmp", "test_backups_#{SecureRandom.hex(4)}")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  test "primary DB를 유효한 SQLite 백업 파일로 만들고 queue 전용 테이블은 제외한다" do
    path = Backup::AppDatabase.call(dir: @dir)

    assert File.exist?(path), "백업 파일이 생성돼야 한다"
    assert File.size(path).positive?, "백업 파일은 비어 있지 않아야 한다"

    header = File.binread(path, 16)
    assert header.start_with?("SQLite format 3"), "유효한 SQLite 헤더가 아니다: #{header.inspect}"

    db = SQLite3::Database.new(path)
    begin
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
    ensure
      db.close
    end

    assert_includes tables, "job_runs", "app(primary) DB의 테이블이 백업에 있어야 한다"
    refute_includes tables, "solid_queue_jobs", "queue 전용 테이블은 백업에 없어야 한다(primary 전용)"
  end
end
