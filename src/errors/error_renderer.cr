require "log"

module QuickHeadlines
  class ErrorRenderer
    include Athena::HTTPKernel::ErrorRendererInterface

    def render(exception : Exception) : AHTTP::Response
      status, message, details = classify_exception(exception)

      Log.error do
        "Error: #{exception.class}: #{exception.message}\n#{exception.backtrace.join("\n")}"
      end

      error_response = {
        "code"    => status.value,
        "message" => message,
      }

      if details && ENV["APP_ENV"]? == "development"
        error_response["details"] = details
      end

      AHTTP::Response.new(error_response.to_json, status, HTTP::Headers{"content-type" => "application/json"})
    end

    private def classify_exception(exception : Exception) : {HTTP::Status, String?, String?}
      case exception
      when AHK::Exception::HTTPException
        {exception.status, exception.message, nil}
      else
        {HTTP::Status::INTERNAL_SERVER_ERROR, "An unexpected error occurred", nil}
      end
    end
  end
end
