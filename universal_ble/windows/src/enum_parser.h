#pragma once

#include <string>

namespace universal_ble
{
	inline std::string device_watcher_status_to_string(const DeviceWatcherStatus result)
	{
		switch (result)
		{
		case DeviceWatcherStatus::Created: return "Created";
		case DeviceWatcherStatus::Aborted: return "Aborted";
		case DeviceWatcherStatus::EnumerationCompleted: return "EnumerationCompleted";
		case DeviceWatcherStatus::Started: return "Started";
		case DeviceWatcherStatus::Stopped: return "Stopped";
		case DeviceWatcherStatus::Stopping: return "Stopping";
		}
		return "";
	}

	inline std::optional<std::string> gatt_communication_status_to_error(const GattCommunicationStatus result)
	{
		switch (result)
		{
		case GattCommunicationStatus::Success:   return std::nullopt;
		case GattCommunicationStatus::Unreachable: return "Unreachable";
		case GattCommunicationStatus::ProtocolError: return "ProtocolError";
		case GattCommunicationStatus::AccessDenied: return "AccessDenied";
		}
		return std::nullopt;
	}

	

	inline std::optional<std::string> device_unpairing_result_to_string(const DeviceUnpairingResultStatus result)
    {
        switch (result)
        {
	        case DeviceUnpairingResultStatus::Failed:  return "Failed to unpair device";
	        case DeviceUnpairingResultStatus::AccessDenied:  return "Access denied";
	        case DeviceUnpairingResultStatus::AlreadyUnpaired:   return "Device is already unpaired";
	        case DeviceUnpairingResultStatus::OperationAlreadyInProgress:  return "OperationAlreadyInProgress";
			case DeviceUnpairingResultStatus::Unpaired:  return std::nullopt;

        }
        return std::nullopt;
    }

	inline std::optional<std::string> parse_pairing_fail_error(const DevicePairingResult& result)
	{
		switch (result.Status())
		{
			case DevicePairingResultStatus::Paired: return std::nullopt;
			case DevicePairingResultStatus::AlreadyPaired: return "AlreadyPaired";
			case DevicePairingResultStatus::ConnectionRejected: return "ConnectionRejected";
			case DevicePairingResultStatus::NotPaired: return "NotPaired";
			case DevicePairingResultStatus::NotReadyToPair: return "NotReadyToPair";
			case DevicePairingResultStatus::TooManyConnections: return "TooManyConnections";
			case DevicePairingResultStatus::HardwareFailure: return "HardwareFailure";
			case DevicePairingResultStatus::AuthenticationTimeout: return "AuthenticationTimeout";
			case DevicePairingResultStatus::AuthenticationNotAllowed: return "AuthenticationNotAllowed";
			case DevicePairingResultStatus::AuthenticationFailure: return "AuthenticationFailure";
			case DevicePairingResultStatus::NoSupportedProfiles: return "NoSupportedProfiles";
			case DevicePairingResultStatus::ProtectionLevelCouldNotBeMet: return "ProtectionLevelCouldNotBeMet";
			case DevicePairingResultStatus::AccessDenied: return "AccessDenied";
			case DevicePairingResultStatus::InvalidCeremonyData: return "InvalidCeremonyData";
			case DevicePairingResultStatus::PairingCanceled: return "PairingCanceled";
			case DevicePairingResultStatus::OperationAlreadyInProgress: return "OperationAlreadyInProgress";
			case DevicePairingResultStatus::RequiredHandlerNotRegistered: return "RequiredHandlerNotRegistered";
			case DevicePairingResultStatus::RejectedByHandler: return "RejectedByHandler";
			case DevicePairingResultStatus::RemoteDeviceHasAssociation: return "RemoteDeviceHasAssociation";
			default: return "Failed to pair";
		}
	}


	inline AvailabilityState get_availability_state_from_radio(const RadioState radio_state)
	{
		switch (radio_state)
		{
		case RadioState::On: return AvailabilityState::poweredOn;
		case RadioState::Off: return AvailabilityState::poweredOff;
		case RadioState::Disabled: return AvailabilityState::unsupported;
		case RadioState::Unknown: return AvailabilityState::unknown;
		}
		return AvailabilityState::unknown;
	}

	inline flutter::EncodableList properties_to_flutter_encodable (const GattCharacteristicProperties properties_value)
	{
		auto properties = flutter::EncodableList();
		if ((properties_value & GattCharacteristicProperties::Broadcast) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::broadcast));
		}
		if ((properties_value & GattCharacteristicProperties::Read) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::read));
		}
		if ((properties_value & GattCharacteristicProperties::Write) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::write));
		}
		if ((properties_value & GattCharacteristicProperties::WriteWithoutResponse) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::writeWithoutResponse));
		}
		if ((properties_value & GattCharacteristicProperties::Notify) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::notify));
		}
		if ((properties_value & GattCharacteristicProperties::Indicate) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::indicate));
		}
		if ((properties_value & GattCharacteristicProperties::AuthenticatedSignedWrites) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::authenticatedSignedWrites));
		}
		if ((properties_value & GattCharacteristicProperties::ExtendedProperties) != GattCharacteristicProperties::None)
		{
			properties.push_back(static_cast<int>(CharacteristicProperty::extendedProperties));
		}
		return properties;
	}
	
}
