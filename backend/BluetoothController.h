#pragma once

#include <QObject>
#include <QString>
#include <QDBusMessage>
#include <QTimer>
#include <QtQml/qqml.h>

#include "BluetoothDeviceModel.h"

class BluetoothController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString currentDeviceName READ currentDeviceName NOTIFY currentDeviceNameChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QString adapterName READ adapterName NOTIFY adapterNameChanged)
    Q_PROPERTY(BluetoothDeviceModel *devices READ devices CONSTANT)

public:
    explicit BluetoothController(QObject *parent = nullptr);
    ~BluetoothController() override;

    bool enabled() const;
    bool scanning() const;
    bool busy() const;
    QString errorMessage() const;
    QString currentDeviceName() const;
    QString statusText() const; // "Scanning..."/"Working..." while busy, else empty
    QString adapterName() const; // this machine's own Bluetooth name, as seen by other devices
    BluetoothDeviceModel *devices() const;

    Q_INVOKABLE void setEnabled(bool on);
    // discover=true also (re)starts a discovery scan; false just re-reads known devices
    Q_INVOKABLE void refreshDevices(bool discover);
    Q_INVOKABLE void pairDevice(const QString &address);
    Q_INVOKABLE void connectDevice(const QString &address);
    Q_INVOKABLE void disconnectDevice(const QString &address);
    Q_INVOKABLE void forgetDevice(const QString &address); // unpairs and removes from known devices

signals:
    void enabledChanged();
    void scanningChanged();
    void busyChanged();
    void errorMessageChanged();
    void currentDeviceNameChanged();
    void statusTextChanged();
    void adapterNameChanged();

private slots:
    void handleInterfacesAdded(const QDBusMessage &msg);
    void handleInterfacesRemoved(const QDBusMessage &msg);
    void handlePropertiesChanged(const QDBusMessage &msg);
    void handleBluezNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);
    void retryFindAdapter(); // covers the cold-boot race: bluetoothd owns the bus name before hci0 is registered

private:
    void setEnabledState(bool on);
    void setScanning(bool on);
    void setBusy(bool on);
    void setErrorMessage(const QString &error);

    void connectToBluez();
    void disconnectFromBluez();
    bool findAdapter();               // populates m_adapterPath, m_adapterPowered
    void populateExistingDevices();   // walks GetManagedObjects for org.bluez.Device1
    void applyDeviceProperties(const QString &objectPath, const QVariantMap &props, bool insertIfMissing);
    QString devicePathForAddress(const QString &address) const;
    void refreshCurrentDeviceName(); // scans the model for a connected device, emits if changed
    void setAdapterName(const QString &name);
    void startAdapterRetry(); // begin/continue polling for the adapter to appear

    void asyncCallNoReply(const QString &objectPath, const QString &interface,
                           const QString &method, const QVariantList &args = {});

    QString m_adapterPath;
    bool m_adapterPowered = false;
    bool m_scanning = false;
    bool m_busy = false;
    QString m_errorMessage;
    QString m_currentDeviceName;
    QString m_adapterName;
    BluetoothDeviceModel *m_devices = nullptr;
    QTimer *m_adapterRetryTimer = nullptr;
    int m_adapterRetriesLeft = 0;
};
