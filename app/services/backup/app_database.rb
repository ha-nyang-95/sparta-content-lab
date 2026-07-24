# app(primary) DB만 VACUUM INTO로 일관 스냅샷 백업 — queue/cache는 별도 연결이라 자동 제외(AD-17)
#
# 일일 백업 절차:
#   - primary(app.sqlite3, 스냅샷 원천)는 소급 재구성 불가라 매일 백업이 필수다.
#   - queue/cache DB는 재생성 가능하므로 백업에서 제외한다(별도 연결/파일이라 자동 제외).
#   - cron 등록 예시(매일 05:00):
#       0 5 * * * cd <app-root> && bin/rails backup:app_db
module Backup
  class AppDatabase
    # dir 에 타임스탬프+랜덤 파일로 primary DB를 VACUUM INTO 백업하고 경로를 반환. 오래된 백업은 rotation.
    # 랜덤 접미사로 같은 초 재실행 충돌(VACUUM INTO 는 대상 파일 존재 시 에러)을 피한다.
    def self.call(dir: Rails.root.join("storage", "backups"), keep: 14)
      FileUtils.mkdir_p(dir)
      target = File.join(dir.to_s, "app-#{Time.current.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(3)}.sqlite3")
      # primary 연결에서만 실행 → queue/cache DB는 이 연결의 대상이 아니라 자동 제외된다.
      connection = ActiveRecord::Base.connection
      connection.execute("VACUUM INTO #{connection.quote(target)}")
      prune(dir: dir, keep: keep)
      target
    end

    # 최신 keep 개만 남기고 오래된 백업을 삭제한다(디스크 무한 증가 방지).
    def self.prune(dir:, keep:)
      backups = Dir.glob(File.join(dir.to_s, "app-*.sqlite3")).sort
      backups[0...-keep].to_a.each { |old| File.delete(old) }
    end
  end
end
