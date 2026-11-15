#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QtQml/qqml.h>

// tracks the default backlight device straight from sysfs: no brightnessctl
// forks, no inotifywait process — a QFileSystemWatcher on the brightness
// attribute drives the change notifications
class BrightnessMonitor final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int brightness READ brightness NOTIFY brightnessChanged)
    Q_PROPERTY(int maxBrightness READ maxBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(qreal percent READ percent NOTIFY brightnessChanged)
    // device discovered once at startup, never changes mid-session
    Q_PROPERTY(QString device READ device CONSTANT)

public:
    explicit BrightnessMonitor(QObject *parent = nullptr);

    int brightness() const { return brightness_; }
    int maxBrightness() const { return max_; }
    qreal percent() const { return max_ > 0 ? qreal(brightness_) / max_ : 0.0; }
    QString device() const { return device_; }

    Q_INVOKABLE void refresh();
    // writes sysfs directly; silently no-ops when the attribute is not
    // writable (user not in the video group)
    Q_INVOKABLE void setBrightness(int value);

signals:
    void brightnessChanged();

private:
    void discover();
    bool readFile(const QString &path, int &out) const;

    QFileSystemWatcher watcher_;
    QString device_; // e.g. "intel_backlight"
    QString sessionPath_; // logind session, resolved once for writes
    int queuedWrite_ = -1;
    int brightness_ = 0;
    int max_ = 0;
};
