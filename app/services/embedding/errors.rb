# Embedding 경계에서 발생하는 예외 계층(설정 오류·보류 마커)
module Embedding
  # 이 경계의 모든 예외의 루트. 호출부는 Embedding::Error 하나로 포착할 수 있다.
  class Error < StandardError; end

  # 키 부재 등 live 모드 실행 불가 설정. 보류(키 대기) 상태를 명확히 알린다.
  class ConfigurationError < Error; end
end
