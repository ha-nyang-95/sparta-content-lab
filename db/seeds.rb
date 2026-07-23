# 운영 2인을 idempotent하게 등록하는 seed (재실행해도 중복 없음)
#
# 실존 인물을 날조하지 않는다 — dev 기본값은 문서화된 placeholder다.
# 실제 운영자 이메일·비밀번호는 ENV로 재정의한다:
#   SEED_OPERATOR1_EMAIL / SEED_OPERATOR2_EMAIL / SEED_OPERATOR_PASSWORD
# 기본 비밀번호는 development/test 전용이며, 그 외 환경에서는 SEED_OPERATOR_PASSWORD를 반드시 명시한다
# (커밋된 기본값이 프로덕션 계정에 쓰이는 것을 막는다 — 회원가입이 없어 seed 계정이 전체 접근면이다).

env_presence = ->(name) { ENV[name].to_s.strip.presence }

emails = [
  env_presence.("SEED_OPERATOR1_EMAIL") || "operator1@sparta.local",
  env_presence.("SEED_OPERATOR2_EMAIL") || "operator2@sparta.local",
]

# 두 이메일이 (정규화 후) 겹치면 "운영 2인" 불변식이 조용히 깨진다 — 중단한다.
if emails.map { |e| e.strip.downcase }.uniq.size < emails.size
  raise "seed 중단: 두 운영자 이메일이 서로 달라야 한다 (#{emails.inspect})"
end

password = env_presence.("SEED_OPERATOR_PASSWORD")
if password.nil?
  unless Rails.env.local? # local? = development || test
    raise "seed 중단: #{Rails.env} 환경에서는 SEED_OPERATOR_PASSWORD를 반드시 설정해야 한다"
  end
  password = "change-me-in-dev" # dev/test 전용 — 프로덕션은 ENV 필수, 첫 로그인 후 교체
end

emails.each do |email|
  User.find_or_create_by!(email_address: email) { |u| u.password = password }
end
