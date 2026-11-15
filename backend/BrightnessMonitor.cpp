#include "BrightnessMonitor.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusObjectPath>
#include <QDir>
#include <QFile>

BrightnessMonitor::BrightnessMonitor(QObject *parent) : QObject(parent) {
    discover();
    connect(&watcher_, &QFileSystemWatcher::fileChanged, this, [this](const QString &) {
        refresh();
        // some devices drop the watch after a write; re-arm when missing
        if (watcher_.files().isEmpty())
            watcher_.addPath(QStringLiteral("/sys/class/backlight/") + device_ + "/brightness");
    });
    if (!device_.isEmpty())
        watcher_.addPath(QStringLiteral("/sys/class/backlight/") + device_ + "/brightness");
    refresh();
    // brightness attributes are root-owned, so writes go through logind's
    // SetBrightness (what brightnessctl does under the hood); resolve the
    // session path once, up front
    auto call = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"), QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"), QStringLiteral("GetSession"));
    call.setArguments({QStringLiteral("auto")});
    QDBusPendingCallWatcher *w =
        new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(call), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QDBusObjectPath> reply = *w;
        if (reply.isValid())
            sessionPath_ = reply.value().path();
        if (sessionPath_ != "" && queuedWrite_ >= 0) {
            const int v = queuedWrite_;
            queuedWrite_ = -1;
            setBrightness(v);
        }
        w->deleteLater();
    });
}

void BrightnessMonitor::discover() {
    const QDir dir(QStringLiteral("/sys/class/backlight"));
    const QStringList entries = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    if (entries.isEmpty())
        return;
    // prefer a kernel-native "raw" device over platform/firmware ones
    // (acpi_video0 etc.) which may not reflect the real panel brightness
    for (const QString &name : entries) {
        QFile type(dir.filePath(name) + "/type");
        if (type.open(QIODevice::ReadOnly | QIODevice::Text) &&
            type.readAll().trimmed() == QByteArrayLiteral("raw")) {
            device_ = name;
            return;
        }
    }
    device_ = entries.first();
}

bool BrightnessMonitor::readFile(const QString &path, int &out) const {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;
    bool ok = false;
    const int v = QString::fromUtf8(f.readAll().trimmed()).toInt(&ok);
    if (ok)
        out = v;
    return ok;
}

void BrightnessMonitor::refresh() {
    if (device_.isEmpty())
        return;
    const QString base = QStringLiteral("/sys/class/backlight/") + device_ + '/';
    int cur = brightness_;
    int max = max_;
    const bool ok = readFile(base + "brightness", cur);
    readFile(base + "max_brightness", max);
    if (ok && (cur != brightness_ || max != max_)) {
        brightness_ = cur;
        max_ = max;
        emit brightnessChanged();
    }
}

void BrightnessMonitor::setBrightness(int value) {
    if (device_.isEmpty() || max_ <= 0)
        return;
    const int clamped = qBound(0, value, max_);
    if (sessionPath_.isEmpty()) {
        queuedWrite_ = clamped; // session lookup still in flight
        return;
    }
    auto msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.freedesktop.login1"), sessionPath_,
        QStringLiteral("org.freedesktop.login1.Session"), QStringLiteral("SetBrightness"));
    msg.setArguments({QStringLiteral("backlight"), device_,
                      QVariant::fromValue(quint32(clamped))});
    QDBusConnection::systemBus().asyncCall(msg);
    // logind applies the write; the sysfs watcher refreshes us from there
}
