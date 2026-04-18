require "log"

module QuickHeadlines
  class ErrorRenderer
    include Athena::Framework::ErrorRendererInterface

    def render(exception : Exception) : ATH::Response
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

      ATH::Response.new(error_response.to_json, status, HTTP::Headers{"content-type" => "application/json"})
    end

    private def classify_exception(exception : Exception) : {HTTP::Status, String?, String?}
      case exception
      when ATH::Exception::HTTPException
        {exception.status, exception.message, nil}
      else
        {HTTP::Status::INTERNAL_SERVER_ERROR, "An unexpected error occurred", nil}
      end
    end
  end
end
