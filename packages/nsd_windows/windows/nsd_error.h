#pragma once

#include <stdexcept>
#include <string>

namespace nsd_windows {

	enum ErrorCause
	{
		ILLEGAL_ARGUMENT,
		ALREADY_ACTIVE,
		MAX_LIMIT,
		OPERATION_NOT_SUPPORTED,
		INTERNAL_ERROR,
	};

	std::string ToErrorCode(const ErrorCause errorCause);

	class NsdError : public std::exception {
	public:
		const std::string message;
		const ErrorCause errorCause;

		// TODO find out why this is necessary, extending std::runtime_error and calling std::runtime_error(message) should be ok?
		virtual char const* what() const throw() override;

		NsdError(const ErrorCause errorCause, const std::string& message);
		virtual ~NsdError();

	};
}
