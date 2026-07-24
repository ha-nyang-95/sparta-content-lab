# YouTube 경계에서 발생하는 예외 계층(쿼터 초과·레이트리밋·설정 오류)
module Youtube
  # 이 경계의 모든 예외의 루트. 호출부는 Youtube::Error 하나로 포착할 수 있다.
  class Error < StandardError; end

  # 공유 풀(10,000 units) 또는 search 버킷(100콜) 한도 초과.
  class QuotaExceeded < Error; end

  # 403 rate/quota 응답. Client 가 지수 백오프로 재시도하며, 상한 초과 시 재raise 된다.
  class RateLimited < Error; end

  # 키 부재 등 live 모드 실행 불가 설정. 보류(키 대기) 상태를 명확히 알린다.
  class ConfigurationError < Error; end
end
