#pragma once

namespace universal_ble
{

    enum class ConnectionState : int
    {
        connected = 0,
        disconnected = 1,
    };

    enum class CharacteristicProperty : int
    {
        broadcast = 0,
        read = 1,
        writeWithoutResponse = 2,
        write = 3,
        notify = 4,
        indicate = 5,
        authenticatedSignedWrites = 6,
        extendedProperties = 7,
    };

    enum class BleInputProperty : int
    {
        disabled = 0,
        notification = 1,
        indication = 2,
    };

    enum class BleOutputProperty : int
    {
        withResponse = 0,
        withoutResponse = 1,
    };

    enum class AvailabilityState : int
    {
        unknown = 0,
        resetting = 1,
        unsupported = 2,
        unauthorized = 3,
        poweredOff = 4,
        poweredOn = 5,
    };

    enum class AdvertisementSectionType : uint8_t
    {
        Flags = 0x01,
        IncompleteService16BitUuids = 0x02,
        CompleteService16BitUuids = 0x03,
        IncompleteService32BitUuids = 0x04,
        CompleteService32BitUuids = 0x05,
        IncompleteService128BitUuids = 0x06,
        CompleteService128BitUuids = 0x07,
        ShortenedLocalName = 0x08,
        CompleteLocalName = 0x09,
        TxPowerLevel = 0x0A,
        ClassOfDevice = 0x0D,
        SimplePairingHashC192 = 0x0E,
        SecurityManagerTKValues = 0x10,
        SecurityManagerOutOfBandFlags = 0x11,
        SlaveConnectionIntervalRange = 0x12,
        ServiceSolicitation16BitUuids = 0x14,
        ServiceSolicitation32BitUuids = 0x1F,
        ServiceSolicitation128BitUuids = 0x15,
        ServiceData16BitUuids = 0x16,
        ServiceData32BitUuids = 0x20,
        ServiceData128BitUuids = 0x21,
        PublicTargetAddress = 0x17,
        RandomTargetAddress = 0x18,
        Appearance = 0x19,
        AdvertisingInterval = 0x1A,
        LEBluetoothDeviceAddress = 0x1B,
        LERole = 0x1C,
        SimplePairingHashC256 = 0x1D,
        ThreeDimensionInformationData = 0x3D,
        ManufacturerSpecificData = 0xFF,
    };

} // namespace universal_ble