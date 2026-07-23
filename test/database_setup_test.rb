# SQLite 멀티DB 설정 검증: WAL·busy_timeout 프래그마와 큐/캐시 DB 격리(AD-12)
require "test_helper"

class DatabaseSetupTest < ActiveSupport::TestCase
  def journal_mode(connection)
    connection.execute("PRAGMA journal_mode").first["journal_mode"].to_s.downcase
  end

  def busy_timeout(connection)
    connection.execute("PRAGMA busy_timeout").first["timeout"]
  end

  test "primary connection uses WAL journal mode" do
    assert_equal "wal", journal_mode(ActiveRecord::Base.connection)
  end

  test "primary connection sets busy_timeout to 5000ms" do
    assert_equal 5000, busy_timeout(ActiveRecord::Base.connection)
  end

  test "queue connection also uses WAL and busy_timeout 5000" do
    conn = SolidQueue::Job.connection
    assert_equal "wal", journal_mode(conn)
    assert_equal 5000, busy_timeout(conn)
  end

  test "cache connection also uses WAL and busy_timeout 5000" do
    conn = SolidCache::Entry.connection
    assert_equal "wal", journal_mode(conn)
    assert_equal 5000, busy_timeout(conn)
  end

  test "Solid Queue is isolated in the queue database file" do
    database = SolidQueue::Job.connection.pool.db_config.database
    assert_includes database, "queue"
  end

  test "Solid Cache is isolated in the cache database file" do
    database = SolidCache::Entry.connection.pool.db_config.database
    assert_includes database, "cache"
  end

  test "primary database is separate from queue and cache files" do
    primary = ActiveRecord::Base.connection.pool.db_config.database
    refute_includes primary, "queue"
    refute_includes primary, "cache"
  end

  test "every environment declares 3 distinct app/cache/queue database files" do
    %w[development test production].each do |env|
      configs = ActiveRecord::Base.configurations.configs_for(env_name: env)
      names = configs.map(&:name)
      assert_includes names, "primary", "#{env}: primary DB 누락"
      assert_includes names, "cache", "#{env}: cache DB 누락"
      assert_includes names, "queue", "#{env}: queue DB 누락"

      paths = configs.map(&:database)
      assert_equal paths.length, paths.uniq.length, "#{env}: DB 파일이 서로 겹침 #{paths.inspect}"
    end
  end

  # 헤드라인 보장 "no Redis" — Gemfile·Gemfile.lock(전이 의존)·config 전체를 스캔한다.
  # 바이너리 config 파일(credentials.yml.enc 등)에서도 크래시하지 않도록 scrub하고,
  # 인라인 주석(`gem "x" # redis 대체`)을 오탐하지 않도록 주석을 제거한 뒤 매칭한다.
  test "no redis references in Gemfile, lockfile, or config" do
    root = Rails.root
    files = Dir.glob(root.join("config/**/*")).select { |p| File.file?(p) }
    files << root.join("Gemfile").to_s
    files << root.join("Gemfile.lock").to_s

    offenders = files.select do |path|
      File.read(path).scrub("").each_line.any? do |raw|
        line = raw.sub(/#.*/, "").strip
        line.match?(/\bredis\b/i)
      end
    end
    assert_empty offenders, "예상치 못한 redis 참조: #{offenders.inspect}"
  end
end
