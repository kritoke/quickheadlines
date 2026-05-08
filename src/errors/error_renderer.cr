require "log"

module QuickHeadlines
  @[ADI::Register]
  class ErrorRenderer
    include Athena::HTTPKernel::ErrorRendererInterface

    def render(exception : Exception) : AHTTP::Response
      status, message, _ = classify_exception(exception)

      if status.value >= 500
        Log.error do
          "Error: #{exception.class}: #{exception.message}\n#{exception.backtrace.join("\n")}"
        end
      end

      AHTTP::Response.new(message || "Error", status, HTTP::Headers{"content-type" => "text/plain"})
    end

    private def classify_exception(exception : Exception) : {HTTP::Status, String?, String?}
      case exception
      when AHK::Exception::NotFound
        {HTTP::Status::NOT_FOUND, "Not Found", nil}
      when AHK::Exception::HTTPException
        {exception.status, exception.message, nil}
      else
        {HTTP::Status::INTERNAL_SERVER_ERROR, "An unexpected error occurred", nil}
      end
    end
  end
end
