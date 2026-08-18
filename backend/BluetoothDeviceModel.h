#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QVector>

class BluetoothDeviceModel final : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        AddressRole,
        PairedRole,
        ConnectedRole,
        SignalRole,
        BatteryRole,
    };

    struct Device {
        QString objectPath;   // e.g., /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
        QString address;      // AA:BB:CC:DD:EE:FF
        QString name;
        bool paired = false;
        bool connected = false;
        int rssi = -1;
        int battery = -1;     // -1 = unknown/not advertised
    };

    explicit BluetoothDeviceModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // upsert by objectPath. returns true if this was a new row
    bool upsertDevice(const Device &device);
    // returns true if a row was actually removed
    bool removeDeviceByPath(const QString &objectPath);
    void updateBattery(const QString &objectPath, int percentage);
    void clear();

    int indexOfPath(const QString &objectPath) const;
    // empty string if nothing is currently connected
    QString connectedDeviceName() const;

private:
    QVector<Device> m_devices;
};
