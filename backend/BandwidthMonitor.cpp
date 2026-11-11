#include "BandwidthMonitor.h"

#include <QDateTime>
#include <QFile>

BandwidthMonitor::BandwidthMonitor(QObject *parent) : QObject(parent) {
    timer_.setInterval(1000);
    connect(&timer_, &QTimer::timeout, this, &BandwidthMonitor::sample);
    sample(); // prime the baseline so the first active tick has a delta
}

double BandwidthMonitor::downloadSpeed() const { return down_; }
double BandwidthMonitor::uploadSpeed() const { return up_; }
bool BandwidthMonitor::active() const { return active_; }

void BandwidthMonitor::setActive(bool on) {
    if (active_ == on)
        return;
    active_ = on;
    if (on) {
        lastRx_ = lastTx_ = -1; // discard stale counters
        sample();
        timer_.start();
    } else {
        timer_.stop();
        down_ = up_ = 0;
        emit speedsChanged();
    }
    emit activeChanged();
}

void BandwidthMonitor::sample() {
    qint64 rx = 0;
    qint64 tx = 0;
    QFile f(QStringLiteral("/proc/net/dev"));
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        // atEnd() is useless on /proc (size 0), so slurp until EOF instead
        const QList<QByteArray> lines = f.readAll().split('\n');
        f.close();
        for (const QByteArray &line : lines) {
            const int colon = line.indexOf(':');
            if (colon <= 0)
                continue;
            const QString ifname = QString::fromLatin1(line.left(colon)).trimmed();
            if (ifname == QStringLiteral("lo"))
                continue;
            QList<QByteArray> parts;
            const QList<QByteArray> fields = line.mid(colon + 1).split(' ');
            for (const QByteArray &b : fields)
                if (!b.isEmpty())
                    parts << b;
            if (parts.size() < 9)
                continue;
            rx += parts.at(0).toLongLong();
            tx += parts.at(8).toLongLong();
        }
    }

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (lastRx_ >= 0 && lastTick_ > 0) {
        const double dt = (now - lastTick_) / 1000.0;
        if (dt > 0) {
            const qint64 drx = rx - lastRx_;
            const qint64 dtx = tx - lastTx_;
            // counter reset (reboot/driver reload): report 0 rather than garbage
            down_ = drx >= 0 ? drx / dt : 0;
            up_ = dtx >= 0 ? dtx / dt : 0;
            emit speedsChanged();
        }
    }
    lastRx_ = rx;
    lastTx_ = tx;
    lastTick_ = now;
}
