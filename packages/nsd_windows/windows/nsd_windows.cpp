#include "nsd_windows.h"

#include "nsd_error.h"
#include "utilities.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <windows.h>

#include <iostream>
#include <memory>
#include <sstream>
#include <vector>

namespace nsd_windows {

	namespace {

		constexpr wchar_t kMessageWindowClass[] = L"NsdWindowsPluginMessageWindow";
		constexpr UINT kDnsEventMessage = WM_APP + 1;

		// "name._type._tcp.local" -> name and "_type._tcp"
		bool SplitInstanceName(const std::string& instanceName, std::string& name, std::string& type) {
			auto components = Split(instanceName, '.');
			if (components.size() < 3) {
				return false;
			}
			name = components[0];
			type = components[1] + "." + components[2];
			return true;
		}

	}  // namespace

	NsdWindows::NsdWindows(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel) {
		this->methodChannel = std::move(methodChannel);
		this->methodChannel->SetMethodCallHandler(
			[nsdWindows = this](const auto& call, auto result) { nsdWindows->HandleMethodCall(call, result);
			});
		this->systemRequirementsSatisfied = CheckSystemRequirementsSatisfied();

		// Created on the platform thread: DNS callbacks post their results here.
		WNDCLASSEXW windowClass{};
		windowClass.cbSize = sizeof(windowClass);
		windowClass.lpfnWndProc = MessageWindowProc;
		windowClass.hInstance = GetModuleHandle(nullptr);
		windowClass.lpszClassName = kMessageWindowClass;
		RegisterClassExW(&windowClass); // fails harmlessly if already registered
		messageWindow = CreateWindowExW(0, kMessageWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
			nullptr, GetModuleHandle(nullptr), nullptr);
		if (messageWindow != nullptr) {
			SetWindowLongPtr(messageWindow, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
		}
	}

	NsdWindows::~NsdWindows() {
		// Callbacks still in flight on DNS threads read their context, so cancel
		// what is running and keep every context alive: the app is shutting down.
		// The method channel is not touched here, the engine is already gone.
		for (auto& [handle, context] : discoveryContextMap) {
			DnsServiceBrowseCancel(&context->canceller);
			context.release();
		}
		for (auto& [handle, context] : resolveContextMap) {
			DnsServiceResolveCancel(&context->canceller);
			context.release();
		}
		for (auto& [handle, context] : registerContextMap) {
			context.release();
		}
		for (auto& context : stoppedDiscoveryContexts) {
			context.release();
		}

		if (messageWindow != nullptr) {
			SetWindowLongPtr(messageWindow, GWLP_USERDATA, 0);
			MSG message;
			while (PeekMessage(&message, messageWindow, kDnsEventMessage, kDnsEventMessage, PM_REMOVE)) {
				FreeDnsEvent(reinterpret_cast<DnsEvent*>(message.lParam));
			}
			DestroyWindow(messageWindow); // later posts fail and free their event
			messageWindow = nullptr;
		}
	}

	void NsdWindows::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& methodCall,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result) {

		const auto& method_name = methodCall.method_name();

		try {
			const auto& arguments = std::get<flutter::EncodableMap>(*methodCall.arguments());

			if (method_name == "startDiscovery") {
				StartDiscovery(arguments, result);
			}
			else if (method_name == "stopDiscovery") {
				StopDiscovery(arguments, result);
			}
			else if (method_name == "register") {
				Register(arguments, result);
			}
			else if (method_name == "resolve") {
				Resolve(arguments, result);
			}
			else if (method_name == "unregister") {
				Unregister(arguments, result);
			}
			else {
				result->NotImplemented();
			}
		}
		catch (const NsdError& e) {
			result->Error(ToErrorCode(e.errorCause), e.what());
		}
		catch (const std::exception& e) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), e.what());
		}
		catch (...) {
			result->Error(ToErrorCode(ErrorCause::INTERNAL_ERROR), "Unknown error");
		}
	}

	void NsdWindows::StartDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		if (!this->systemRequirementsSatisfied) {
			throw NsdError(ErrorCause::OPERATION_NOT_SUPPORTED, "Plugin requires at least Windows 10, build 18362");
		}

		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");

		if (discoveryContextMap.count(handle) != 0) {
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Handle already in use");
		}

		auto context = std::make_unique<DiscoveryContext>();
		context->window = messageWindow;
		context->handle = handle;

		auto queryName = ToUtf16(serviceType + ".local");

		DNS_SERVICE_BROWSE_REQUEST request{};
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.QueryName = queryName.c_str();
		request.pBrowseCallback = &DnsServiceBrowseCallback;
		request.pQueryContext = context.get();

		auto status = DnsServiceBrowse(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		discoveryContextMap[handle] = std::move(context);
		methodChannel->InvokeMethod("onDiscoveryStartSuccessful", CreateMethodResult({ { "handle", handle } }));
		result->Success();
	}

	void NsdWindows::StopDiscovery(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = Deserialize<std::string>(arguments, "handle");

		auto it = discoveryContextMap.find(handle);
		if (it == discoveryContextMap.end()) {
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Unknown handle");
		}

		auto& context = *it->second.get();

		const auto status = DnsServiceBrowseCancel(&context.canceller);
		// The browse can still call back after the cancel, so its context stays alive.
		stoppedDiscoveryContexts.push_back(std::move(it->second));
		discoveryContextMap.erase(it);

		if (status != ERROR_SUCCESS) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		methodChannel->InvokeMethod("onDiscoveryStopSuccessful", CreateMethodResult({ { "handle", handle } }));
		result->Success();
	}

	void NsdWindows::Resolve(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceName = Deserialize<std::string>(arguments, "service.name");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");

		if (resolveContextMap.count(handle) != 0) {
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Handle already in use");
		}

		auto context = std::make_unique<ResolveContext>();
		context->window = messageWindow;
		context->handle = handle;

		auto queryName = ToUtf16(serviceName + "." + serviceType + ".local");

		DNS_SERVICE_RESOLVE_REQUEST request{};
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.QueryName = const_cast<PWSTR>(queryName.c_str());
		request.pResolveCompletionCallback = &DnsServiceResolveCallback;
		request.pQueryContext = context.get();

		const auto status = DnsServiceResolve(&request, &context->canceller);

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		resolveContextMap[handle] = std::move(context);
		result->Success();
	}

	void NsdWindows::Register(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		if (!this->systemRequirementsSatisfied) {
			throw NsdError(ErrorCause::OPERATION_NOT_SUPPORTED, "Plugin requires at least Windows 10, build 18362");
		}

		auto handle = Deserialize<std::string>(arguments, "handle");
		auto serviceName = Deserialize<std::string>(arguments, "service.name");
		auto serviceType = Deserialize<std::string>(arguments, "service.type");
		auto servicePort = Deserialize<int>(arguments, "service.port");
		auto serviceTxt = FlutterTxtToWindowsTxt(DeserializeOptional<flutter::EncodableMap>(arguments, "service.txt"));

		auto computerName = GetComputerName();

		// see https://docs.microsoft.com/en-us/windows/win32/api/windns/nf-windns-dnsserviceconstructinstance

		auto serviceNameW = ToUtf16(serviceName + "." + serviceType + ".local");
		auto hostNameW = computerName + L".local";

		PDNS_SERVICE_INSTANCE pServiceInstance = DnsServiceConstructInstance(
			serviceNameW.c_str(), // PCWSTR pServiceName
			hostNameW.c_str(), // PCWSTR pHostName
			nullptr, // PIP4_ADDRESS pIp4 (optional)
			nullptr, // PIP6_ADDRESS pIp6 (optional)
			static_cast<WORD>(servicePort), // WORD wPort
			0, // WORD wPriority
			0, // WORD wWeight
			serviceTxt->size, // DWORD dwPropertiesCount
			serviceTxt->pKeyPointers, // PCWSTR* keys
			serviceTxt->pValuePointers // PCWSTR* values
		);

		if (registerContextMap.count(handle) != 0) {
			DnsServiceFreeInstance(pServiceInstance);
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Handle already in use");
		}

		auto context = std::make_unique<RegisterContext>();
		context->window = messageWindow;
		context->handle = handle;

		auto& request = context->request;
		request.Version = DNS_QUERY_REQUEST_VERSION1;
		request.InterfaceIndex = 0;
		request.pServiceInstance = pServiceInstance;
		request.pRegisterCompletionCallback = &DnsServiceRegisterCallback;
		request.pQueryContext = context.get();
		request.unicastEnabled = false;

		auto status = DnsServiceRegister(&request, &context->canceller);

		DnsServiceFreeInstance(request.pServiceInstance);
		request.pServiceInstance = nullptr; // will be replaced by OnServiceResolved()
		request.pRegisterCompletionCallback = nullptr; // will be replaced by Unregister()

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		registerContextMap[handle] = std::move(context);
		result->Success();
	}

	void NsdWindows::Unregister(const flutter::EncodableMap& arguments, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result)
	{
		auto handle = Deserialize<std::string>(arguments, "handle");

		auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			throw NsdError(ErrorCause::ILLEGAL_ARGUMENT, "Unknown handle");
		}

		auto& context = *it->second.get();
		auto& request = context.request;

		request.pRegisterCompletionCallback = &DnsServiceUnregisterCallback; // set callback for request reuse

		auto status = DnsServiceDeRegister(&request, nullptr);

		DnsServiceFreeInstance(request.pServiceInstance);
		request.pServiceInstance = nullptr;

		if (status != DNS_REQUEST_PENDING) {
			throw NsdError(ErrorCause::INTERNAL_ERROR, GetErrorMessage(status));
		}

		result->Success();
	}

	// Platform thread: results posted by the DNS callbacks.

	void NsdWindows::OnServiceDiscovered(DnsEvent& event)
	{
		if (event.status != ERROR_SUCCESS || !event.serviceInfo.has_value()) {
			return;
		}

		// A stopped discovery can still deliver results; they are dropped.
		auto contextIt = discoveryContextMap.find(event.handle);
		if (contextIt == discoveryContextMap.end()) {
			return;
		}

		const std::string& handle = event.handle;
		ServiceInfo& serviceInfo = event.serviceInfo.value();
		std::vector<ServiceInfo>& services = contextIt->second->services;

		auto it = FindIf(services, [compare = serviceInfo](ServiceInfo& current) -> bool {
			return
				current.name == compare.name &&
				current.type == compare.type;
			});

		if (serviceInfo.status == ServiceInfo::STATUS_FOUND) {

			if (it == services.end()) {
				services.push_back(serviceInfo);
				methodChannel->InvokeMethod("onServiceDiscovered", CreateMethodResult({
						{ "handle", handle },
						{ "service.name", serviceInfo.name.value() },
						{ "service.type", serviceInfo.type.value() },
					}));
			}
		}
		else {

			if (it != services.end()) {
				services.erase(it);
				methodChannel->InvokeMethod("onServiceLost", CreateMethodResult({
						{ "handle", handle },
						{ "service.name", serviceInfo.name.value() },
						{ "service.type", serviceInfo.type.value() },
					}));
			}
		}
	}

	void NsdWindows::OnServiceResolved(DnsEvent& event)
	{
		const std::string& handle = event.handle;
		PDNS_SERVICE_INSTANCE pInstance = event.instance;

		auto it = resolveContextMap.find(handle);
		if (it == resolveContextMap.end()) {
			return;
		}
		// A resolve calls back once: its context is done.
		resolveContextMap.erase(it);

		std::string serviceName;
		std::string serviceType;
		if (event.status != ERROR_SUCCESS || pInstance == nullptr ||
			!SplitInstanceName(ToUtf8(pInstance->pszInstanceName), serviceName, serviceType)) { // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
			methodChannel->InvokeMethod("onResolveFailed", CreateMethodResult({
					{ "handle", handle },
					{ "error.cause", ToErrorCode(ErrorCause::INTERNAL_ERROR) },
					{ "error.message", event.status != ERROR_SUCCESS ? GetErrorMessage(event.status) : "Invalid service instance"s },
				}));
			return;
		}

		auto servicePort = pInstance->wPort;
		auto serviceHost = ToUtf8(pInstance->pszHostName);
		auto serviceTxt = WindowsTxtToFlutterTxt(pInstance->dwPropertyCount, pInstance->keys, pInstance->values);

		methodChannel->InvokeMethod("onResolveSuccessful", CreateMethodResult({
				{ "handle", handle },
				{ "service.type", serviceType },
				{ "service.name", serviceName },
				{ "service.port", servicePort },
				{ "service.host", serviceHost },
				{ "service.txt", serviceTxt },
			}));
	}

	void NsdWindows::OnServiceRegistered(DnsEvent& event)
	{
		const std::string& handle = event.handle;

		auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			return;
		}

		auto& context = *it->second.get();
		auto& request = context.request;

		std::string serviceName;
		std::string serviceType;
		if (event.status != ERROR_SUCCESS || event.instance == nullptr ||
			!SplitInstanceName(ToUtf8(event.instance->pszInstanceName), serviceName, serviceType)) { // "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
			registerContextMap.erase(it);
			methodChannel->InvokeMethod("onRegistrationFailed", CreateMethodResult({
					{ "handle", handle },
					{ "error.cause", ToErrorCode(ErrorCause::INTERNAL_ERROR) },
					{ "error.message", event.status != ERROR_SUCCESS ? GetErrorMessage(event.status) : "Invalid service instance"s },
				}));
			return;
		}

		auto servicePort = event.instance->wPort;
		auto serviceHost = ToUtf8(event.instance->pszHostName);
		auto serviceTxt = WindowsTxtToFlutterTxt(event.instance->dwPropertyCount, event.instance->keys, event.instance->values);

		// the existing request must be reused with the newly received instance for unregistering
		if (request.pServiceInstance != nullptr) {
			DnsServiceFreeInstance(request.pServiceInstance);
		}
		request.pServiceInstance = event.instance;
		event.instance = nullptr; // owned by the request now

		methodChannel->InvokeMethod("onRegistrationSuccessful", CreateMethodResult({
				{ "handle", handle },
				{ "service.type", serviceType },
				{ "service.name", serviceName },
				{ "service.port", servicePort },
				{ "service.host", serviceHost },
				{ "service.txt", serviceTxt },
			}));
	}

	void NsdWindows::OnServiceUnregistered(DnsEvent& event)
	{
		const std::string& handle = event.handle;

		auto it = registerContextMap.find(handle);
		if (it == registerContextMap.end()) {
			return;
		}

		registerContextMap.erase(it);

		if (event.status != ERROR_SUCCESS) {
			methodChannel->InvokeMethod("onUnregistrationFailed", CreateMethodResult({
					{ "handle", handle },
					{ "error.cause", ToErrorCode(ErrorCause::INTERNAL_ERROR) },
					{ "error.message", GetErrorMessage(event.status) },
				}));
			return;
		}

		methodChannel->InvokeMethod("onUnregistrationSuccessful", CreateMethodResult({ { "handle", handle } }));
	}

	void NsdWindows::HandleDnsEvent(DnsEvent& event)
	{
		switch (event.kind) {
		case DnsEvent::Kind::BROWSE:
			OnServiceDiscovered(event);
			break;
		case DnsEvent::Kind::RESOLVE:
			OnServiceResolved(event);
			break;
		case DnsEvent::Kind::REGISTER:
			OnServiceRegistered(event);
			break;
		case DnsEvent::Kind::UNREGISTER:
			OnServiceUnregistered(event);
			break;
		}
	}

	LRESULT CALLBACK NsdWindows::MessageWindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
	{
		if (message != kDnsEventMessage) {
			return DefWindowProc(hwnd, message, wparam, lparam);
		}

		auto* event = reinterpret_cast<DnsEvent*>(lparam);
		auto* nsdWindows = reinterpret_cast<NsdWindows*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
		if (nsdWindows != nullptr) {
			try {
				nsdWindows->HandleDnsEvent(*event);
			}
			catch (...) {
				// never let a malformed DNS result end the app
			}
		}
		FreeDnsEvent(event);
		return 0;
	}

	void NsdWindows::FreeDnsEvent(DnsEvent* event) noexcept
	{
		if (event == nullptr) {
			return;
		}
		if (event->instance != nullptr) {
			DnsServiceFreeInstance(event->instance);
		}
		delete event;
	}

	void NsdWindows::PostDnsEvent(HWND window, std::unique_ptr<DnsEvent> event) noexcept
	{
		// Fails once the plugin (and its window) is gone.
		if (window != nullptr && PostMessage(window, kDnsEventMessage, 0, reinterpret_cast<LPARAM>(event.get()))) {
			event.release();
			return;
		}
		FreeDnsEvent(event.release());
	}

	// DNS threadpool threads: copy what is needed, then post it to the platform thread.
	// Nothing may throw out of these, an exception here ends the app.

	void NsdWindows::DnsServiceBrowseCallback(const DWORD status, LPVOID context, PDNS_RECORD records) noexcept
	{
		try {
			const auto& discoveryContext = *static_cast<DiscoveryContext*>(context);
			auto event = std::make_unique<DnsEvent>();
			event->kind = DnsEvent::Kind::BROWSE;
			event->handle = discoveryContext.handle;
			event->status = status;
			if (status == ERROR_SUCCESS && records != nullptr) {
				event->serviceInfo = GetServiceInfoFromRecords(records);
			}
			const HWND window = discoveryContext.window;
			if (records != nullptr) {
				// must be deleted as described here: https://docs.microsoft.com/en-us/windows/win32/api/windns/nc-windns-dns_service_browse_callback
				DnsRecordListFree(records, DnsFreeRecordList);
				records = nullptr;
			}
			PostDnsEvent(window, std::move(event));
		}
		catch (...) {
			if (records != nullptr) {
				DnsRecordListFree(records, DnsFreeRecordList);
			}
		}
	}

	void NsdWindows::DnsServiceResolveCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance) noexcept
	{
		try {
			const auto& resolveContext = *static_cast<ResolveContext*>(context);
			auto event = std::make_unique<DnsEvent>();
			event->kind = DnsEvent::Kind::RESOLVE;
			event->handle = resolveContext.handle;
			event->status = status;
			event->instance = pInstance;
			pInstance = nullptr;
			PostDnsEvent(resolveContext.window, std::move(event));
		}
		catch (...) {
			if (pInstance != nullptr) {
				DnsServiceFreeInstance(pInstance);
			}
		}
	}

	void NsdWindows::DnsServiceRegisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance) noexcept
	{
		try {
			const auto& registerContext = *static_cast<RegisterContext*>(context);
			auto event = std::make_unique<DnsEvent>();
			event->kind = DnsEvent::Kind::REGISTER;
			event->handle = registerContext.handle;
			event->status = status;
			event->instance = pInstance;
			pInstance = nullptr;
			PostDnsEvent(registerContext.window, std::move(event));
		}
		catch (...) {
			if (pInstance != nullptr) {
				DnsServiceFreeInstance(pInstance);
			}
		}
	}

	void NsdWindows::DnsServiceUnregisterCallback(const DWORD status, LPVOID context, PDNS_SERVICE_INSTANCE pInstance) noexcept
	{
		if (pInstance != nullptr) {
			DnsServiceFreeInstance(pInstance); // not used
		}
		try {
			const auto& registerContext = *static_cast<RegisterContext*>(context);
			auto event = std::make_unique<DnsEvent>();
			event->kind = DnsEvent::Kind::UNREGISTER;
			event->handle = registerContext.handle;
			event->status = status;
			PostDnsEvent(registerContext.window, std::move(event));
		}
		catch (...) {
		}
	}

	std::optional<ServiceInfo> NsdWindows::GetServiceInfoFromRecords(const PDNS_RECORD& records) {

		// record properties see https://docs.microsoft.com/en-us/windows/win32/api/windns/ns-windns-dns_recordw
		// seen: DNS_TYPE_A (0x0001), DNS_TYPE_TEXT (0x0010), DNS_TYPE_AAAA (0x001c), DNS_TYPE_SRV (0x0021)

		for (auto record = records; record; record = record->pNext) {
			if (record->wType == DNS_TYPE_PTR) { // 0x0012
				return GetServiceInfoFromPtrRecord(record);
			}
		}

		return std::nullopt;
	}

	std::optional<nsd_windows::ServiceInfo> NsdWindows::GetServiceInfoFromPtrRecord(const PDNS_RECORD& record)
	{
		auto nameHost = ToUtf8(record->Data.PTR.pNameHost); // PTR rdata field DNAME, e.g. "HP Color LaserJet MFP M277dw (C162F4)._http._tcp.local"
		auto ttl = record->dwTtl;

		std::string name;
		std::string type;
		if (!SplitInstanceName(nameHost, name, type)) {
			return std::nullopt; // malformed record
		}

		ServiceInfo serviceInfo;
		serviceInfo.name = name;
		serviceInfo.type = type;
		serviceInfo.status = (ttl > 0) ? ServiceInfo::STATUS_FOUND : ServiceInfo::STATUS_LOST;

		//std::cout << GetTimeNow() << " " << "Record: PTR: name: " << name << ", domain name: " << nameHost << ", ttl: " << ttl << std::endl;
		return serviceInfo;
	}

}  // namespace nsd_windows
