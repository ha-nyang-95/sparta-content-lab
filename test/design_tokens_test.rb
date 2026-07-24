# DESIGN.md §10 토큰 이관·Tailwind v3 핀·원시 팔레트 색 금지를 가드하는 테스트 (Story 1.3)
require "test_helper"
require "tailwindcss/upstream"

class DesignTokensTest < ActiveSupport::TestCase
  CONFIG_PATH = Rails.root.join("config", "tailwind.config.js")
  BUILD_PATH  = Rails.root.join("app", "assets", "builds", "tailwind.css")

  # DESIGN.md §10 전체 색 토큰(단일 원천). 하나라도 어긋나면 드리프트다.
  REQUIRED_HEXES = %w[
    #EEF2FE #DCE4FD #2E5BE6 #1145DD #0E37B0
    #E7F6EC #C6EBD1 #159C49 #0F7A38
    #FEF3E4 #F59E0B #B45309
    #15803D
    #F2F4F7 #4B5563 #FEF1E3 #F56B04 #FEEEEF #C31334
    #FBFCFD #FFFFFF #F7F8FA #E5E7EB #EEF1F5
    #111827 #374151 #6B7280 #9CA3AF
  ].freeze

  # (a) config 가 DESIGN.md §10 값을 **전부** 그대로 담는다(부분 검증은 침묵 드리프트를 허용한다).
  test "config carries all DESIGN.md section 10 token values verbatim" do
    cfg = File.read(CONFIG_PATH)

    REQUIRED_HEXES.each do |hex|
      assert_includes cfg, hex, "§10 색 토큰 #{hex} 누락/변경"
    end

    # 폰트 스택
    ["Pretendard", "Noto Sans KR", "Noto Sans JP", "system-ui"].each do |f|
      assert_includes cfg, f, "폰트 스택 #{f} 누락"
    end

    # radius
    { "card" => "12px", "control" => "8px", "chip" => "6px" }.each do |k, v|
      assert_includes cfg, "#{k}:'#{v}'", "radius #{k} #{v} 누락/변경"
    end

    # fontSize (size + 대표 weight)
    assert_match(/score:\s*\['40px'.*fontWeight:'800'/,  cfg, "fontSize score 40px/800 누락")
    assert_match(/h1:\s*\['28px'.*fontWeight:'700'/,     cfg, "fontSize h1 28px/700 누락")
    assert_match(/h2:\s*\['20px'/,  cfg, "fontSize h2 20px 누락")
    assert_match(/h3:\s*\['18px'/,  cfg, "fontSize h3 18px 누락")
    assert_match(/nav:\s*\['15px'/, cfg, "fontSize nav 15px 누락")
    assert_match(/body:\s*\['14px'/, cfg, "fontSize body 14px 누락")
    assert_match(/caption:\s*\['13px'/, cfg, "fontSize caption 13px 누락")
    assert_match(/label:\s*\['12px'/, cfg, "fontSize label 12px 누락")

    # boxShadow (세 종의 특징 시그니처)
    assert_includes cfg, "rgba(16,24,40,0.04)", "shadow-card 시그니처 누락"
    assert_includes cfg, "rgba(16,24,40,0.08)", "shadow-cardHover 시그니처 누락"
    assert_includes cfg, "0 4px 12px rgba(16,24,40,0.10)", "shadow-dropdown 누락"
  end

  # (b) Tailwind 은 v3 로 핀된다: gem 은 2.x 라인, 번들 CLI 는 v3.x (v4 아님).
  test "tailwind is pinned to v3 (gem 2.x line, bundled CLI v3.x)" do
    lock = File.read(Rails.root.join("Gemfile.lock"))
    assert_match(/tailwindcss-rails \(2\./, lock, "tailwindcss-rails 가 2.x 라인이 아님")

    normalized = Tailwindcss::Upstream::VERSION.delete_prefix("v") # 예: "3.4.13"
    assert normalized.start_with?("3."), "번들 Tailwind CLI 가 v3.x 가 아님: #{Tailwindcss::Upstream::VERSION}"
    refute normalized.start_with?("4."), "번들 Tailwind CLI 가 v4 임(핀 실패): #{Tailwindcss::Upstream::VERSION}"
  end

  # (c) 빌드가 토큰을 실제 값으로 컴파일한다. 뷰 내용이 아니라 내구성 프로브
  #     (app/views/shared/_tailwind_token_probe.html.erb)에 앵커해 뷰 교체(1.4)에 깨지지 않는다.
  #     Tailwind v3 는 색 유틸을 rgb(<r> <g> <b>/…) 로 방출한다: #1145DD = rgb(17 69 221).
  test "build compiles token utilities to the section 10 values" do
    assert system("bin/rails", "tailwindcss:build",
                  chdir: Rails.root.to_s, out: File::NULL, err: File::NULL),
           "tailwindcss:build 실패"

    assert File.exist?(BUILD_PATH), "빌드 산출물 tailwind.css 없음"
    css = File.read(BUILD_PATH)
    assert_includes css, ".bg-primary-600",  "primary-600 유틸이 빌드에 없음(프로브 content 스캔 실패)"
    assert_includes css, "rgb(17 69 221",    "primary-600 이 #1145DD(rgb 17 69 221)로 컴파일 안 됨"
    assert_includes css, "rgb(21 156 73",    "success-600 이 #159C49(rgb 21 156 73)로 컴파일 안 됨"
  end

  # (d) 원시 Tailwind 팔레트 색·임의 hex 직접 사용이 없다(토큰만 허용).
  #     config content 가 스캔하는 소스 전체(views·helpers·js·public)를 검사한다 —
  #     §10 의 performance_band_class 는 헬퍼에 살므로 헬퍼도 반드시 포함한다.
  test "no raw tailwind palette colors or arbitrary hex in scanned sources" do
    palette = %w[slate gray zinc neutral stone red orange amber yellow lime green
                 emerald teal cyan sky blue indigo violet purple fuchsia pink rose]
    prefixes = %w[bg text border ring from to via fill stroke divide outline
                  decoration accent caret placeholder shadow]
    named         = /\b(?:#{prefixes.join('|')})-(?:#{palette.join('|')})-\d{2,3}\b/
    arbitrary_hex = /\b(?:#{prefixes.join('|')})-\[#[0-9a-fA-F]{3,8}\]/

    sources = %w[app/views app/helpers app/javascript].flat_map do |dir|
      Dir[Rails.root.join(dir, "**", "*.{erb,haml,slim,html,rb,js}")]
    end
    sources += Dir[Rails.root.join("public", "*.html")]

    offenders = sources.select do |path|
      content = File.read(path)
      content.match?(named) || content.match?(arbitrary_hex)
    end
    assert_empty offenders,
      "원시 Tailwind 팔레트 색/임의 hex 직접 사용 발견(토큰만 허용): #{offenders.join(', ')}"
  end
end
