#include "utilities.h"

#include <codecvt>
#include <sstream>
#include <algorithm>

namespace nsd_windows {

	flutter::EncodableMap WindowsTxtToFlutterTxt(const DWORD count, const PWSTR* keys, const PWSTR* values) {
		flutter::EncodableMap txt;

		for (DWORD i = 0; i < count; i++) {

			auto key = ToUtf8(keys[i]);
			auto codeUnitsString = ToUtf8(values[i]);
			auto codeUnitsList = std::vector<unsigned char>(codeUnitsString.begin(), codeUnitsString.end());

			if (codeUnitsList.empty()) {

				// Windows doesn't distinguish between "empty value" ("foo=") and "no value" (e.g. "foo") as described in RFC6763,
				// instead all "no value" will be empty. We treat both these value types as "no value" to be consistent with the other platforms.
				// see https://datatracker.ietf.org/doc/html/rfc6763#section-6.4

				txt[key] = std::monostate();
			}
			else {
				txt[key] = codeUnitsList;
			}
		}
		return txt;
	}

	std::unique_ptr<WindowsTxt> FlutterTxtToWindowsTxt(std::optional<const flutter::EncodableMap> txt) {

		if (!txt.has_value() || txt->size() == 0) {
			return std::make_unique<WindowsTxt>();
		}

		auto count = txt->size();
		auto windowsTxt = std::make_unique<WindowsTxt>();

		for (auto it = txt->begin(); it != txt->end(); it++) {

			auto key = ToUtf16(std::get<std::string>(it->first));
			windowsTxt->keys.push_back(key);

			if (std::holds_alternative<std::vector<unsigned char>>(it->second)) {

				auto& codeUnitsList = std::get<std::vector<unsigned char>>(it->second); // list of UTF-8 code units
				std::string codeUnitsString(codeUnitsList.begin(), codeUnitsList.end());
				auto value = ToUtf16(codeUnitsString); // Non-UTF-8 code units such as '255' will be replaced with U+FFFD by MultiByteToWideChar, so they will not survive the journey
				windowsTxt->values.push_back(value);
			}
			else {
				windowsTxt->values.push_back(L"");
			}
		}

		windowsTxt->size = static_cast<DWORD>(count);
		windowsTxt->keyPointers = GetPointers(windowsTxt->keys);
		windowsTxt->valuePointers = GetPointers(windowsTxt->values);
		windowsTxt->pKeyPointers = &windowsTxt->keyPointers[0];
		windowsTxt->pValuePointers = &windowsTxt->valuePointers[0];

		return std::move(windowsTxt);
	}

	std::unique_ptr<flutter::EncodableValue> CreateMethodResult(const flutter::EncodableMap values) {
		return std::move(std::make_unique<flutter::EncodableValue>(values));
	}

	std::wstring ToUtf16(const std::string string)
	{
		// see https://stackoverflow.com/a/69410299/8707976

		if (string.empty())
		{
			return L"";
		}

		auto size_needed = MultiByteToWideChar(CP_UTF8, 0, &string.at(0), (int)string.size(), nullptr, 0);
		if (size_needed <= 0)
		{
			throw std::runtime_error("MultiByteToWideChar() failed: " + std::to_string(size_needed));
			// see https://docs.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar for error codes
		}

		std::wstring result(size_needed, 0);
		MultiByteToWideChar(CP_UTF8, 0, &string.at(0), (int)string.size(), &result.at(0), size_needed);
		return result;
	}

	std::string ToUtf8(const std::wstring wide_string)
	{
		// see https://stackoverflow.com/a/69410299/8707976

		if (wide_string.empty())
		{
			return "";
		}

		auto size_needed = WideCharToMultiByte(CP_UTF8, 0, &wide_string.at(0), (int)wide_string.size(), nullptr, 0, nullptr, nullptr);
		if (size_needed <= 0)
		{
			throw std::runtime_error("WideCharToMultiByte() failed: " + std::to_string(size_needed));
			// see https://docs.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar for error codes
		}

		std::string result(size_needed, 0);
		WideCharToMultiByte(CP_UTF8, 0, &wide_string.at(0), (int)wide_string.size(), &result.at(0), size_needed, nullptr, nullptr);
		return result;
	}

	std::string ToUtf8(PCWSTR wide_string)
	{
		if (wide_string == nullptr)
		{
			return "";
		}
		return ToUtf8(std::wstring(wide_string));
	}

	std::string GetErrorMessage(const DWORD messageId)
	{
		// see https://docs.microsoft.com/en-us/windows/win32/debug/retrieving-the-last-error-code

		LPVOID pBuffer = nullptr;

		FormatMessage(
			FORMAT_MESSAGE_ALLOCATE_BUFFER |
			FORMAT_MESSAGE_FROM_SYSTEM |
			FORMAT_MESSAGE_IGNORE_INSERTS,
			nullptr,
			messageId,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			(LPTSTR)&pBuffer,
			0,
			nullptr
		);

		std::string message = ToUtf8((LPTSTR)pBuffer);

		LocalFree(pBuffer);
		return message;
	}

	std::string GetLastErrorMessage()
	{
		return GetErrorMessage(GetLastError());
	}

	std::vector<std::string> Split(const std::string text, const char delimiter) {
		std::istringstream in(text);
		std::vector<std::string> out;
		std::string current;
		while (std::getline(in, current, delimiter)) {
			out.push_back(current);
		}
		return out;
	}

	std::string GetTimeNow() {

		// see https://stackoverflow.com/a/38034148/8707976

		std::tm bt{};
		auto timer = std::time_t(std::time(0));
		localtime_s(&bt, &timer);
		char buf[64]{};
		return { buf, std::strftime(buf, sizeof(buf), "%F %T", &bt) };
	}

	std::wstring GetComputerName() {
		DWORD size = 0;
		GetComputerNameEx(ComputerNameDnsHostname, nullptr, &size);
		std::vector<wchar_t> computerName(size);
		if (!GetComputerNameEx(ComputerNameDnsHostname, &computerName[0], &size)) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, "Could not determine computer name");
		}
		return &computerName[0];
	}

	std::vector<PCWSTR> GetPointers(std::vector<std::wstring>& in)
	{
		std::vector<PCWSTR> out;
		std::transform(in.begin(), in.end(), std::back_inserter(out), [](const std::wstring& string) -> PCWSTR {
			return string.c_str();
			});
		return out;
	}

	bool CheckSystemRequirementsSatisfied()
	{
		// see https://stackoverflow.com/a/52122386/8707976

		NTSTATUS(WINAPI * RtlGetVersion)(LPOSVERSIONINFOEXW) = nullptr;
		OSVERSIONINFOEXW osInfo{};

		*(FARPROC*)&RtlGetVersion = GetProcAddress(GetModuleHandleA("ntdll"), "RtlGetVersion");

		if (NULL == RtlGetVersion)
		{
			return false; // if the function is not supported, the OS is too old
		}

		osInfo.dwOSVersionInfoSize = sizeof(osInfo);
		RtlGetVersion(&osInfo);
		ULONG majorVersion = osInfo.dwMajorVersion;
		ULONG buildNumber = osInfo.dwBuildNumber;

		// Plugin requires 1903 - 19H1 - May 2019 Update - Build No. 18362
		// (see also https://github.com/mumble-voip/mumble/pull/4494)

		return (majorVersion >= 10 && buildNumber >= 18362);
	}
}