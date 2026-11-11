#pragma once

#include <QObject>
#include <QTimer>
#include <QtQml/qqml.h>

// samples /proc/net/dev once a second and exposes total network
// throughput (all non-loopback interfaces) in bytes per second
class BandwidthMonitor final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(double downloadSpeed READ downloadSpeed NOTIFY speedsChanged)
    Q_PROPERTY(double uploadSpeed READ uploadSpeed NOTIFY speedsChanged)
    // sampling only runs while active, so the shell pays nothing when closed
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit BandwidthMonitor(QObject *parent = nullptr);
    ~BandwidthMonitor() override = default;

    double downloadSpeed() const;
    double uploadSpeed() const;
    bool active() const;
    void setActive(bool on);

signals:
    void speedsChanged();
    void activeChanged();

private:
    void sample();

    QTimer timer_;
    qint64 lastRx_ = -1;
    qint64 lastTx_ = -1;
    qint64 lastTick_ = 0;
    double down_ = 0;
    double up_ = 0;
    bool active_ = false;
};
