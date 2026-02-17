#include "windows_iap_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <variant>

#pragma once
#include <winrt/Windows.Services.Store.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <shobjidl.h>

#include <chrono>
#include <iomanip>
#include <flutter/event_sink.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler.h>
#include <flutter/event_stream_handler_functions.h>
#include <winrt/base.h>
#include <winrt/base.h>

using namespace winrt;
using namespace Windows::Services::Store;
using namespace Windows::Foundation::Collections;
namespace foundation = Windows::Foundation;

namespace windows_iap
{

	//////////////////////////////////////////////////////////////////////// BEGIN OF MY CODE //////////////////////////////////////////////////////////////
	flutter::PluginRegistrarWindows *_registrar;

	HWND GetRootWindow(flutter::FlutterView *view)
	{
		return ::GetAncestor(view->GetNativeWindow(), GA_ROOT);
	}

	StoreContext getStore()
	{
		StoreContext store = StoreContext::GetDefault();
		auto initWindow = store.try_as<IInitializeWithWindow>();
		if (initWindow != nullptr)
		{
			initWindow->Initialize(GetRootWindow(_registrar->GetView()));
		}
		return store;
	}

	std::wstring s2ws(const std::string &s)
	{
		int len;
		int slength = (int)s.length() + 1;
		len = MultiByteToWideChar(CP_ACP, 0, s.c_str(), slength, 0, 0);
		wchar_t *buf = new wchar_t[len];
		MultiByteToWideChar(CP_ACP, 0, s.c_str(), slength, buf, len);
		std::wstring r(buf);
		delete[] buf;
		return r;
	}

	std::string debugString(std::vector<std::string> vt)
	{

		std::stringstream ss;
		ss << "( ";
		for (auto t : vt)
		{
			ss << t << ", ";
		}
		ss << " )\n";
		return ss.str();
	}

	std::string getExtendedErrorString(winrt::hresult error)
	{
		const HRESULT IAP_E_UNEXPECTED = 0x803f6107L;
		std::string message;
		if (error.value == IAP_E_UNEXPECTED)
		{
			message = "This Product has not been properly configured.";
		}
		else
		{
			message = "ExtendedError: " + std::to_string(error.value);
		}
		return message;
	}

	foundation::IAsyncAction makePurchase(hstring storeId, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> resultCallback)
	{
		StorePurchaseResult result = co_await getStore().RequestPurchaseAsync(storeId);

		if (result.ExtendedError().value != S_OK)
		{
			resultCallback->Error(std::to_string(result.ExtendedError().value), getExtendedErrorString(result.ExtendedError().value));
			co_return;
		}
		int32_t returnCode;
		switch (result.Status())
		{
		case StorePurchaseStatus::AlreadyPurchased:
			returnCode = 1;
			break;

		case StorePurchaseStatus::Succeeded:
			returnCode = 0;
			break;

		case StorePurchaseStatus::NotPurchased:
			returnCode = 2;
			break;

		case StorePurchaseStatus::NetworkError:
			returnCode = 3;
			break;

		case StorePurchaseStatus::ServerError:
			returnCode = 4;
			break;

		default:
			auto status = reinterpret_cast<int32_t *>(result.Status());
			resultCallback->Error(std::to_string(*status), "Product was not purchased due to an unknown error.");
			co_return;
			break;
		}

		resultCallback->Success(flutter::EncodableValue(returnCode));
	}

	std::string productsToString(std::vector<StoreProduct> products)
	{
		std::stringstream ss;
		ss << "[";
		for (int i = 0; i < products.size(); i++)
		{
			auto product = products.at(i);
			ss << "{";
			ss << "\"title\":\"" << to_string(product.Title()) << "\",";
			ss << "\"description\":\"" << to_string(product.Description()) << "\",";
			ss << "\"price\":\"" << to_string(product.Price().FormattedPrice()) << "\",";
			ss << "\"inCollection\":" << (product.IsInUserCollection() ? "true" : "false") << ",";
			ss << "\"productKind\":\"" << to_string(product.ProductKind()) << "\",";
			ss << "\"storeId\":\"" << to_string(product.StoreId()) << "\"";
			ss << "}";
			if (i != products.size() - 1)
			{
				ss << ",";
			}
		}
		ss << "]";

		return ss.str();
	}

	foundation::IAsyncAction getProducts(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> resultCallback)
	{
		auto result = co_await getStore().GetAssociatedStoreProductsAsync({L"Consumable", L"Durable", L"UnmanagedConsumable"});
		if (result.ExtendedError().value != S_OK)
		{
			resultCallback->Error(std::to_string(result.ExtendedError().value), getExtendedErrorString(result.ExtendedError()));
		}
		else if (result.Products().Size() == 0)
		{
			resultCallback->Success(flutter::EncodableValue("[]"));
		}
		else
		{
			std::vector<StoreProduct> products;
			for (IKeyValuePair<hstring, StoreProduct> addOn : result.Products())
			{
				StoreProduct product = addOn.Value();
				products.push_back(product);
			}
			std::string productsString = productsToString(products);
			resultCallback->Success(flutter::EncodableValue(productsString));
		}
	}

	std::string getStoreLicenseString(StoreLicense license)
	{
		std::stringstream ss;
		ss << "{";
		ss << "\"isActive\":" << (license.IsActive() ? "true" : "false") << ",";
		ss << "\"skuStoreId\":\"" << to_string(license.SkuStoreId()) << "\",";
		ss << "\"inAppOfferToken\":\"" << to_string(license.InAppOfferToken()) << "\",";
		ss << "\"expirationDate\":" << license.ExpirationDate().time_since_epoch().count() << "";
		ss << "}";

		return ss.str();
	}

	foundation::IAsyncAction getAddonLicenses(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> resultCallback)
	{
		auto result = co_await getStore().GetAppLicenseAsync();
		auto addonLicenses = result.AddOnLicenses();

		std::map<flutter::EncodableValue, flutter::EncodableValue> mapLicenses;

		for (IKeyValuePair<hstring, StoreLicense> addonLicense : addonLicenses)
		{
			mapLicenses[flutter::EncodableValue(to_string(addonLicense.Key()))] = flutter::EncodableValue(getStoreLicenseString(addonLicense.Value()));
		}

		resultCallback->Success(flutter::EncodableValue(mapLicenses));
	}

	/// <summary>
	///  need to test in real app on store
	/// </summary>
	foundation::IAsyncAction checkPurchase(std::string storeId, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> resultCallback)
	{
		auto result = co_await getStore().GetAppLicenseAsync();

		if (result.IsActive())
		{

			auto addonLicenses = result.AddOnLicenses();

			for (IKeyValuePair<hstring, StoreLicense> addonLicense : addonLicenses)
			{
				StoreLicense license = addonLicense.Value();

				if (storeId.compare("") == 0)
				{
					// Truong hop storeId empty => bat ky Add-on nao co IsActive = true deu return true
					if (license.IsActive())
					{
						resultCallback->Success(flutter::EncodableValue(true));
						co_return;
					}
				}
				else
				{
					// Truong hop storeId not empty => check key = storeId
					auto key = to_string(addonLicense.Key());
					if (key.compare(storeId) == 0)
					{
						resultCallback->Success(flutter::EncodableValue(license.IsActive()));
						co_return;
					}
				}
			}
			// truong hop duyet het add-on license nhung vang khong tim thay IsActive = true thi return false
			resultCallback->Success(flutter::EncodableValue(false));
		}
		else
		{
			resultCallback->Success(flutter::EncodableValue(false));
		}
	}

	/// <summary>
	/// need to test in real app on store
	/// </summary>
	/// <summary>
	/// need to test in real app on store
	/// </summary>
	foundation::IAsyncAction getTrialStatusAndRemainingDays(
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> resultCallback)
	{
		auto store = getStore();
		auto license = co_await store.GetAppLicenseAsync();

		flutter::EncodableMap result;
		result[flutter::EncodableValue("isTrial")] = flutter::EncodableValue(true);
		result[flutter::EncodableValue("remainingDays")] = flutter::EncodableValue("");
		result[flutter::EncodableValue("isActive")] = flutter::EncodableValue(license.IsActive());
		result[flutter::EncodableValue("isTrialOwnedByThisUser")] = flutter::EncodableValue(license.IsTrialOwnedByThisUser());
		

		if (!license.IsActive())
		{
			resultCallback->Success(flutter::EncodableValue(result));
			co_return;
		}

		if (license.IsTrial())
		{
			result[flutter::EncodableValue("isTrial")] = flutter::EncodableValue(true);

			auto expirationDate = license.ExpirationDate();

			// dt is your winrt::Windows::Foundation::DateTime
			std::time_t t = winrt::clock::to_time_t(expirationDate);  // Convert to time_t (UTC seconds since 1970)
			std::tm tm_buf;
			localtime_s(&tm_buf, &t);  // Safe version

			std::wstringstream wss;
			wss << std::put_time(&tm_buf, L"%Y-%m-%d %H:%M:%S");  // Custom format

			winrt::hstring readable = winrt::hstring{ wss.str() };
			std::string utf8 = winrt::to_string(readable);  // Converts hstring to UTF-8 std::string

			result[flutter::EncodableValue("remainingDays")] = flutter::EncodableValue(utf8);
		}
		else {
			result[flutter::EncodableValue("isTrial")] = flutter::EncodableValue(false);

		}

		resultCallback->Success(flutter::EncodableValue(result));
	}

	foundation::IAsyncAction getCustomerPurchaseIdKey(
		std::string serviceTicket,
		std::string publisherUserId,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> resultCallback)
	{
		if (serviceTicket.empty())
		{
			resultCallback->Error("invalid-args", "serviceTicket is required.");
			co_return;
		}
		if (publisherUserId.empty())
		{
			resultCallback->Error("invalid-args", "publisherUserId is required.");
			co_return;
		}

		try
		{
			auto purchaseId = co_await getStore().GetCustomerPurchaseIdAsync(
				to_hstring(serviceTicket),
				to_hstring(publisherUserId));

			resultCallback->Success(flutter::EncodableValue(to_string(purchaseId)));
		}
		catch (const winrt::hresult_error &error)
		{
			resultCallback->Error(
				std::to_string(error.code().value),
				to_string(error.message()));
		}
	}

	//////////////////////////////////////////////////////////////////////// END OF MY CODE //////////////////////////////////////////////////////////////

	// static
	void WindowsIapPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows *registrar)
	{
		_registrar = registrar;

		auto channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
				registrar->messenger(), "windows_iap",
				&flutter::StandardMethodCodec::GetInstance());

		auto plugin = std::make_unique<WindowsIapPlugin>();

		channel->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto &call, auto result)
			{
				plugin_pointer->HandleMethodCall(call, std::move(result));
			});

		registrar->AddPlugin(std::move(plugin));
	}

	WindowsIapPlugin::WindowsIapPlugin() {}

	WindowsIapPlugin::~WindowsIapPlugin() {}

	void WindowsIapPlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue> &method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
	{
		if (method_call.method_name().compare("makePurchase") == 0)
		{
			auto args = std::get<flutter::EncodableMap>(*method_call.arguments());
			auto storeId = std::get<std::string>(args[flutter::EncodableValue("storeId")]);
			makePurchase(to_hstring(storeId), std::move(result));
		}
		else if (method_call.method_name().compare("getProducts") == 0)
		{
			getProducts(std::move(result));
		}
		else if (method_call.method_name().compare("checkPurchase") == 0)
		{
			auto args = std::get<flutter::EncodableMap>(*method_call.arguments());
			auto storeId = std::get<std::string>(args[flutter::EncodableValue("storeId")]);
			checkPurchase(storeId, std::move(result));
		}
		else if (method_call.method_name().compare("getAddonLicenses") == 0)
		{
			getAddonLicenses(std::move(result));
		}
		else if (method_call.method_name().compare("getTrialStatusAndRemainingDays") == 0)
		{
			getTrialStatusAndRemainingDays(std::move(result));
		}
		else if (method_call.method_name().compare("getCustomerPurchaseIdKey") == 0)
		{
			if (method_call.arguments() == nullptr)
			{
				result->Error("invalid-args", "Arguments are required.");
				return;
			}
			auto args = std::get<flutter::EncodableMap>(*method_call.arguments());
			auto serviceTicketIt = args.find(flutter::EncodableValue("serviceTicket"));
			auto publisherUserIdIt = args.find(flutter::EncodableValue("publisherUserId"));
			if (serviceTicketIt == args.end() || !std::holds_alternative<std::string>(serviceTicketIt->second))
			{
				result->Error("invalid-args", "serviceTicket must be a string.");
				return;
			}
			if (publisherUserIdIt == args.end() || !std::holds_alternative<std::string>(publisherUserIdIt->second))
			{
				result->Error("invalid-args", "publisherUserId must be a string.");
				return;
			}
			auto serviceTicket = std::get<std::string>(serviceTicketIt->second);
			auto publisherUserId = std::get<std::string>(publisherUserIdIt->second);
			getCustomerPurchaseIdKey(serviceTicket, publisherUserId, std::move(result));
		}
		else
		{
			result->NotImplemented();
		}
	}

} // namespace windows_iap
