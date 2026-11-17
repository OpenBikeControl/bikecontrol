#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <windns.h>

#include <memory>
#include <optional>
#include <vector>

#pragma warning(disable : 4458) // declaration hides class member (used intentionally in method parameters vs local variables)
#pragma comment(lib, "dnsapi.lib")


namespace nsd_windows {

	class NsdWindows;

	struct ServiceInfo {

		enum Status {
			STATUS_FOUND,
			STATUS_LOST
		};

		std::optional<std::string> name;
		std::optional<std::string> type;
		std::optional<std::string> host;
		std::optional<int> port;
		Status status;
	};


	// DNS callbacks run on threadpool threads. They only read their context's
	// handle and message window and post a DnsEvent to that window, so the plugin
	// state and the method channel are only ever touched on the platform thread.

	struct DiscoveryContext {

		HWND window;
		std::string handle;
		DNS_SERVICE_CANCEL canceller;
		std::vector<ServiceInfo> services;
	};


	struct ResolveContext {

		HWND window;
		std::string handle;
		DNS_SERVICE_CANCEL canceller;
	};

	struct RegisterContext {

		HWND window;
		std::string handle;
		DNS_SERVICE_CANCEL canceller;
		DNS_SERVICE_REGISTER_REQUEST request;
	};

	// A DNS callback result, owned by the message queue until the platform thread
	// handles it.
	struct DnsEvent {

		enum class Kind {
			BROWSE,
			RESOLVE,
			REGISTER,
			UNREGISTER
		};

		Kind kind;
		std::string handle;
		DWORD status;
		std::optional<ServiceInfo> serviceInfo; // BROWSE
		PDNS_SERVICE_INSTANCE instance = nullptr; // RESOLVE, REGISTER: owned by the event
	};

	class NsdWindows {
	public:

		static void DnsServiceBrowseCallback(const DWORD status, LPVOID context, PDNS_RECORD records) noexcept;
		static void DnsServiceRegisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance) noexcept;
		static void DnsServiceUnregisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance) noexcept;
		static void DnsServiceResolveCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance) noexcept;

		NsdWindows(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel);
		virtual ~NsdWindows();

		NsdWindows(const NsdWindows&) = delete; // disallow copy
		NsdWindows& operator=(const NsdWindows&) = delete; // disallow assign

	private:

		static LRESULT CALLBACK MessageWindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
		static void PostDnsEvent(HWND window, std::unique_ptr<DnsEvent> event) noexcept;
		static void FreeDnsEvent(DnsEvent* event) noexcept;

		void HandleDnsEvent(DnsEvent& event);
		void OnServiceDiscovered(DnsEvent& event);
		void OnServiceResolved(DnsEvent& event);
		void OnServiceRegistered(DnsEvent& event);
		void OnServiceUnregistered(DnsEvent& event);

		static std::optional<ServiceInfo> GetServiceInfoFromRecords(const PDNS_RECORD& records);
		static std::optional<ServiceInfo> GetServiceInfoFromPtrRecord(const PDNS_RECORD& record);

		std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel;
		std::map<std::string, std::unique_ptr<DiscoveryContext>> discoveryContextMap;
		std::map<std::string, std::unique_ptr<RegisterContext>> registerContextMap;
		std::map<std::string, std::unique_ptr<ResolveContext>> resolveContextMap;

		// A cancelled browse can still call back with its context, so stopped
		// discoveries stay alive until the plugin goes away.
		std::vector<std::unique_ptr<DiscoveryContext>> stoppedDiscoveryContexts;

		HWND messageWindow = nullptr;

		bool systemRequirementsSatisfied;

		void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue>& method_call,
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);

		void StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);
		void Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result);

	};

}  // namespace nsd_windows
