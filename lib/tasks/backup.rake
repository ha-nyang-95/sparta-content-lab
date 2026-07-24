# app(primary) DB 백업 rake — 일일 백업 절차의 진입점(Backup::AppDatabase 위임)
namespace :backup do
  desc "app(primary) DB를 VACUUM INTO로 백업하고 생성 경로를 출력한다"
  task app_db: :environment do
    path = Backup::AppDatabase.call
    puts path
  end
end
