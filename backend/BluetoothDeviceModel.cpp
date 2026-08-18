#include "BluetoothDeviceModel.h"

BluetoothDeviceModel::BluetoothDeviceModel(QObject *parent)
    : QAbstractListModel(parent) {}

int BluetoothDeviceModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_devices.size();
}

QVariant BluetoothDeviceModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_devices.size())
        return {};

    const Device &d = m_devices.at(index.row());
    switch (role) {
    case NameRole:      return d.name.isEmpty() ? d.address : d.name;
    case AddressRole:   return d.address;
    case PairedRole:    return d.paired;
    case ConnectedRole: return d.connected;
    case SignalRole:    return d.rssi;
    case BatteryRole:   return d.battery;
    default:            return {};
    }
}

QHash<int, QByteArray> BluetoothDeviceModel::roleNames() const {
    return {
        { NameRole,      "name" },
        { AddressRole,   "address" },
        { PairedRole,    "paired" },
        { ConnectedRole, "connected" },
        { SignalRole,    "signal" },
        { BatteryRole,   "battery" },
    };
}

int BluetoothDeviceModel::indexOfPath(const QString &objectPath) const {
    for (int i = 0; i < m_devices.size(); ++i)
        if (m_devices.at(i).objectPath == objectPath) return i;
    return -1;
}

QString BluetoothDeviceModel::connectedDeviceName() const {
    for (const auto &d : m_devices) {
        if (d.connected) return d.name.isEmpty() ? d.address : d.name;
    }
    return {};
}

bool BluetoothDeviceModel::upsertDevice(const Device &device) {
    const int existing = indexOfPath(device.objectPath);
    if (existing >= 0) {
        m_devices[existing] = device;
        const QModelIndex idx = index(existing);
        emit dataChanged(idx, idx);
        return false;
    }

    beginInsertRows(QModelIndex(), m_devices.size(), m_devices.size());
    m_devices.append(device);
    endInsertRows();
    return true;
}

bool BluetoothDeviceModel::removeDeviceByPath(const QString &objectPath) {
    const int existing = indexOfPath(objectPath);
    if (existing < 0) return false;

    beginRemoveRows(QModelIndex(), existing, existing);
    m_devices.removeAt(existing);
    endRemoveRows();
    return true;
}

void BluetoothDeviceModel::clear() {
    if (m_devices.isEmpty()) return;
    beginResetModel();
    m_devices.clear();
    endResetModel();
}

void BluetoothDeviceModel::updateBattery(const QString &objectPath, int percentage) {
    const int idx = indexOfPath(objectPath);
    if (idx < 0) return;
    if (m_devices[idx].battery == percentage) return;
    m_devices[idx].battery = percentage;
    const QModelIndex mi = index(idx);
    emit dataChanged(mi, mi, { BatteryRole });
}
