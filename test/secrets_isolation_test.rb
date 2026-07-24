# API 키 하드코딩 부재·서비스 경계 밖 키 참조 부재·.env 격리를 소스 스캔으로 가드
require "test_helper"

class SecretsIsolationTest < ActiveSupport::TestCase
  ROOT = Rails.root.to_s

  # 소스 파일 스캔 대상. git 추적 여부와 무관하게 파일시스템을 본다
  # (미추적 파일에 심긴 키·커밋 전 유출을 잡기 위해). 단, 다음은 제외한다:
  # - .env(실제 키의 정당한 위치, gitignore), 빌드/런타임 산출물
  # - _bmad-output(예시 패턴 포함 문서), config 암호화 키, 이 테스트 자신(AIza regex 리터럴 보유)
  def scan_files(include_env_example: false)
    files = %w[app lib config db test bin].flat_map { |d| Dir.glob(File.join(ROOT, d, "**", "*")) }
    files += Dir.glob(File.join(ROOT, "*")) # 루트 일반 파일(Gemfile 등, 닷파일 제외)
    files << File.join(ROOT, ".env.example") if include_env_example
    files.select { |p| File.file?(p) }.reject { |p| excluded?(p) }.uniq
  end

  def excluded?(path)
    rel = path.sub("#{ROOT}/", "")
    rel == ".env" ||
      rel.start_with?("_bmad-output/") ||
      rel.start_with?("app/assets/builds/") ||
      rel == "config/master.key" ||
      rel.start_with?("config/credentials") ||
      rel == "test/secrets_isolation_test.rb"
  end

  test "리포 소스에 하드코딩된 키(Google API 키·PEM private key)가 없다" do
    google_key  = /AIza[0-9A-Za-z_-]{20,}/
    private_key = /-----BEGIN [A-Z ]*PRIVATE KEY-----/
    offenders = scan_files.select do |path|
      content = File.read(path, encoding: "BINARY")
      content.match?(google_key) || content.match?(private_key)
    end
    assert_empty offenders, "하드코딩된 키 발견: #{offenders.inspect}"
  end

  test "추적 소스가 API 키에 비어있지 않은 값을 대입하지 않는다(.env.example 포함)" do
    # .env.example 은 YOUTUBE_API_KEY= / GEMINI_API_KEY= 를 빈 값으로 유지해야 한다.
    assign_pattern = /^\s*(?:export\s+)?(?:YOUTUBE_API_KEY|GEMINI_API_KEY)\s*=\s*(\S.*)$/
    offenders = []
    scan_files(include_env_example: true).each do |path|
      File.foreach(path) do |line|
        offenders << "#{path}: #{line.strip}" if line.match?(assign_pattern)
      end
    rescue ArgumentError
      next # 바이너리 파일 스킵
    end
    assert_empty offenders, "API 키에 값이 대입됨: #{offenders.inspect}"
  end

  test "app/services 밖(lib·config 포함)에서는 API 키 ENV 를 참조하지 않는다(전방 가드)" do
    key_names = /YOUTUBE_API_KEY|GEMINI_API_KEY/
    sources = %w[app lib config].flat_map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }
    outside = sources.reject { |path| path.include?("/app/services/") }
    offenders = outside.select { |path| File.read(path).match?(key_names) }
    assert_empty offenders, "app/services 밖에서 API 키 참조: #{offenders.inspect}"
  end

  test ".env 는 gitignore 되어 있다" do
    system("git", "check-ignore", "--quiet", ".env")
    assert_equal 0, $?.exitstatus, ".env 가 gitignore 되지 않았다"
  end
end
