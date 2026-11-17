#include "nsd_error.h"

namespace nsd_windows {

	std::string ToErrorCode(const ErrorCause errorCause)
	{
		switch (errorCause) {
		case ILLEGAL_ARGUMENT:
			return "illegalArgument";

		case ALREADY_ACTIVE:
			return "alreadyActive";

		case MAX_LIMIT:
			return "maxLimit";

		case OPERATION_NOT_SUPPORTED:
			return "operationNotSupported";

		case INTERNAL_ERROR:
		default:
			return "internalError";
		}
	}

	const char* NsdError::what() const throw() {
		return message.c_str(); 
	}

	NsdError::NsdError(const ErrorCause errorCause, const std::string& message) : errorCause(errorCause), message(message)
	{
	}

	NsdError::~NsdError()
	{
	}
}
