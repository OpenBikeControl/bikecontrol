#pragma once

#include "nsd_error.h"

#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <functional>
#include <optional>
#include <map>
#include <variant>
#include <vector>

using namespace std::string_literals;

namespace nsd_windows {

	// provides c-style pointers but frees the values along with the parent object 
	struct WindowsTxt {

		WindowsTxt() {};
		virtual ~WindowsTxt() {};
		WindowsTxt(const WindowsTxt&) = delete; // copying would invalidate c pointersv

		DWORD size = 0;
		PCWSTR* pKeyPointers = nullptr;
		PCWSTR* pValuePointers = nullptr;

	private:

		friend std::unique_ptr<WindowsTxt> FlutterTxtToWindowsTxt(std::optional<const flutter::EncodableMap> txt);

		std::vector<std::wstring> keys;
		std::vector<std::wstring> values;
		std::vector<PCWSTR> keyPointers;
		std::vector<PCWSTR> valuePointers;
	};

	template<class T>
	std::optional<T> DeserializeOptional(const flutter::EncodableMap& arguments, const std::string key)
	{
		auto it = arguments.find(key);

		if (it == arguments.end() || it->second.IsNull() || std::holds_alternative<std::monostate>(it->second)) {
			return std::nullopt;
		}

		return std::get<T>(it->second);
	}

	template<class T, typename F>
	T Deserialize(const flutter::EncodableMap& arguments, const std::string key, const F&& throwFunc)
	{
		std::optional<T> valueO = DeserializeOptional<T>(arguments, key);
		if (!valueO.has_value()) {
			throwFunc();
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Missing value: "s + key);
		}

		return valueO.value();
	}

	template<class T>
	T Deserialize(const flutter::EncodableMap& arguments, const std::string key)
	{
		return Deserialize<T>(arguments, key, []() {});
	}

	template <class T, typename F> typename std::vector<T>::iterator FindIf(std::vector<T>& values, const F&& predicate) {
		for (auto it = values.begin(); it != values.end(); it++) {
			if (predicate(*it)) {
				return it;
			}
		}
		return values.end();
	}

	flutter::EncodableMap WindowsTxtToFlutterTxt(const DWORD count, const PWSTR* keys, const PWSTR* values);
	std::unique_ptr<WindowsTxt> FlutterTxtToWindowsTxt(std::optional<const flutter::EncodableMap> txt);

	std::unique_ptr<flutter::EncodableValue> CreateMethodResult(const flutter::EncodableMap values);

	std::wstring ToUtf16(const std::string string);
	std::string ToUtf8(const std::wstring wide_string);
	// Null-safe: DNS records and instances can carry null strings.
	std::string ToUtf8(PCWSTR wide_string);
	std::string GetErrorMessage(const DWORD messageId);
	std::string GetLastErrorMessage();
	std::vector<std::string> Split(const std::string text, const char delimiter);
	std::string GetTimeNow();
	std::wstring GetComputerName();
	std::vector<PCWSTR> GetPointers(std::vector<std::wstring>& in);
	bool CheckSystemRequirementsSatisfied();
}
