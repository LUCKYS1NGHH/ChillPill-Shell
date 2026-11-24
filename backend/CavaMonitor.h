#pragma once

#include <QByteArray>
#include <QList>
#include <QObject>
#include <QProcess>
#include <QTemporaryFile>
#include <QTimer>
#include <QtQml/qqmlregistration.h>
#include <memory>

// Spawns cava (raw/ascii output), parses frames off the GUI hot path and
// exposes ready-to-draw bar values (0..1) to QML.
class CavaMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int barCount READ barCount WRITE setBarCount NOTIFY barCountChanged)
    Q_PROPERTY(int skipLow READ skipLow WRITE setSkipLow NOTIFY skipLowChanged)
    Q_PROPERTY(int skipHigh READ skipHigh WRITE setSkipHigh NOTIFY skipHighChanged)
    Q_PROPERTY(int framerate READ framerate WRITE setFramerate NOTIFY framerateChanged)
    Q_PROPERTY(QList<qreal> values READ values NOTIFY valuesChanged)

public:
    explicit CavaMonitor(QObject *parent = nullptr);
    ~CavaMonitor() override;

    bool available() const { return m_available; }
    bool active() const { return m_active; }
    int barCount() const { return m_barCount; }
    int skipLow() const { return m_skipLow; }
    int skipHigh() const { return m_skipHigh; }
    int framerate() const { return m_framerate; }
    QList<qreal> values() const { return m_values; }

    void setActive(bool on);
    void setBarCount(int n);
    void setSkipLow(int n);
    void setSkipHigh(int n);
    void setFramerate(int fps);

signals:
    void activeChanged();
    void barCountChanged();
    void skipLowChanged();
    void skipHighChanged();
    void framerateChanged();
    void valuesChanged();

private slots:
    void onReadyRead();
    void onFinished();

private:
    void start();
    void stop();
    void scheduleReconfigure();
    void resetValues();
    void parseFrame(const QByteArray &line);

    bool m_available = false;
    bool m_active = false;
    bool m_stopping = false;
    int m_barCount = 10;
    int m_skipLow = 2;
    int m_skipHigh = 0;
    int m_framerate = 60;

    QProcess m_proc;
    std::unique_ptr<QTemporaryFile> m_cfg;
    QByteArray m_buf;
    QList<qreal> m_values;
    QTimer m_restartTimer;
    QTimer m_reconfigTimer;
};
