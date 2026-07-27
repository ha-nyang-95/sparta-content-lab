# Embedding 경계에서 발생하는 예외 계층(설정 오류·보류 마커)
module Embedding
  # 이 경계의 모든 예외의 루트. 호출부는 Embedding::Error 하나로 포착할 수 있다.
  class Error < StandardError; end

  # 키 부재 등 live 모드 실행 불가 설정. 보류(키 대기) 상태를 명확히 알린다.
  class ConfigurationError < Error; end

  # Gemini 크레딧/쿼터 소진(HTTP 429 RESOURCE_EXHAUSTED) — 빌링 충전 전까지 임베딩 불가.
  # 일반 Error 와 구분해 UpsertVectors 가 조기 중단하고, 잡·설정 화면이 '빌링 소진' 경보를 띄우게 한다.
  class QuotaExhausted < Error; end
end
