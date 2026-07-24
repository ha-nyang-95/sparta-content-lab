# 90일 지난 일별 스냅샷을 (소유자·ISO주)당 최신 1개만 남기고 얇게 씨닝한다(AD-6)
module Snapshot
  class RollupOldStats
    # date < (today - cutoff_days) 인 행을 (owner_id, ISO주)별 최신 date 1개만 남기고 삭제.
    # MVP 규모(소량)라 Ruby 메모리 그룹핑으로 충분하다 — 대규모는 SQL 씨닝으로 대체.
    def self.call(cutoff_days: 90, today: Time.zone.today)
      cutoff = today - cutoff_days
      deleted = 0
      deleted += thin(VideoDailyStat, :video_id, cutoff)
      deleted += thin(ChannelDailyStat, :channel_id, cutoff)
      deleted
    end

    def self.thin(model, owner_key, cutoff)
      old_rows = model.where("date < ?", cutoff)
      delete_ids = []
      old_rows.group_by { |row| [row[owner_key], row.date.strftime("%G-%V")] }.each_value do |group|
        keep = group.max_by(&:date)
        delete_ids.concat(group.reject { |row| row.id == keep.id }.map(&:id))
      end
      return 0 if delete_ids.empty?

      # IN 리스트가 SQLite 변수 상한(SQLITE_MAX_VARIABLE_NUMBER)을 넘지 않게 배치 삭제한다.
      delete_ids.each_slice(900).sum { |slice| model.where(id: slice).delete_all }
    end

    # VACUUM 은 트랜잭션 안에서 실행할 수 없다 — 트랜잭션 안이면 명확히 실패시킨다.
    # 일일 잡(2.5)이 씨닝 뒤 주기적으로(트랜잭션 밖에서) 호출한다. Rails 트랜잭셔널 테스트에서 실행 검증 생략.
    def self.vacuum!
      if ActiveRecord::Base.connection.transaction_open?
        raise "VACUUM 은 트랜잭션 밖에서만 실행할 수 있다"
      end

      ActiveRecord::Base.connection.execute("VACUUM")
    end
  end
end
