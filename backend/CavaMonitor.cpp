#include "CavaMonitor.h"

#include <QStandardPaths>
#include <algorithm>

CavaMonitor::CavaMonitor(QObject *parent)
    : QObject(parent)
    , m_available(!QStandardPaths::findExecutable(QStringLiteral("cava")).isEmpty())
{
    resetValues();

    m_restartTimer.setSingleShot(true);
    m_restartTimer.setInterval(1000);
    connect(&m_restartTimer, &QTimer::timeout, this, &CavaMonitor::start);

    // coalesces several property changes (barCount + skipLow...) into one restart
    m_reconfigTimer.setSingleShot(true);
    m_reconfigTimer.setInterval(50);
    connect(&m_reconfigTimer, &QTimer::timeout, this, [this] {
        if (m_proc.state() != QProcess::NotRunning) {
            stop();
            start();
        }
    });

    connect(&m_proc, &QProcess::readyReadStandardOutput, this, &CavaMonitor::onReadyRead);
    connect(&m_proc, &QProcess::finished, this, &CavaMonitor::onFinished);
}

CavaMonitor::~CavaMonitor()
{
    stop();
}

void CavaMonitor::setActive(bool on)
{
    if (m_active == on)
        return;
    m_active = on;
    emit activeChanged();
    if (on)
        start();
    else
        stop();
}

#define PILL_SETTER(Name, member, minVal, maxVal, sig)        \
    void CavaMonitor::set##Name(int n)                        \
    {                                                         \
        n = std::clamp(n, minVal, maxVal);                    \
        if (member == n)                                      \
            return;                                           \
        member = n;                                           \
        emit sig();                                           \
        scheduleReconfigure();                                \
    }

PILL_SETTER(SkipLow, m_skipLow, 0, 32, skipLowChanged)
PILL_SETTER(SkipHigh, m_skipHigh, 0, 32, skipHighChanged)
PILL_SETTER(Framerate, m_framerate, 10, 144, framerateChanged)
#undef PILL_SETTER

void CavaMonitor::setBarCount(int n)
{
    n = std::clamp(n, 1, 128);
    if (m_barCount == n)
        return;
    m_barCount = n;
    resetValues();
    emit barCountChanged();
    scheduleReconfigure();
}

void CavaMonitor::scheduleReconfigure()
{
    if (m_proc.state() != QProcess::NotRunning)
        m_reconfigTimer.start();
}

void CavaMonitor::resetValues()
{
    m_values = QList<qreal>(m_barCount, 0.0);
    emit valuesChanged();
}

void CavaMonitor::start()
{
    if (!m_available || !m_active || m_proc.state() != QProcess::NotRunning)
        return;

    m_cfg = std::make_unique<QTemporaryFile>();
    if (!m_cfg->open())
        return;

    const int bins = m_skipLow + m_barCount + m_skipHigh;
    const QByteArray cfg = QByteArrayLiteral("[general]\n")
        + "bars = " + QByteArray::number(bins) + "\n"
        + "framerate = " + QByteArray::number(m_framerate) + "\n"
        + "[output]\n"
          "method = raw\n"
          "raw_target = /dev/stdout\n"
          "data_format = ascii\n"
          "ascii_max_range = 100\n"
          "bar_delimiter = 59\n"
          "frame_delimiter = 10\n";
    m_cfg->write(cfg);
    m_cfg->flush();

    m_buf.clear();
    m_stopping = false;
    m_proc.start(QStringLiteral("cava"), { QStringLiteral("-p"), m_cfg->fileName() });
}

void CavaMonitor::stop()
{
    m_restartTimer.stop();
    m_reconfigTimer.stop();
    if (m_proc.state() != QProcess::NotRunning) {
        m_stopping = true;
        m_proc.terminate();
        if (!m_proc.waitForFinished(300)) {
            m_proc.kill();
            m_proc.waitForFinished(300);
        }
    }
    m_buf.clear();
    m_cfg.reset();
    resetValues();
}

void CavaMonitor::onFinished()
{
    m_buf.clear();
    if (m_active && !m_stopping)
        m_restartTimer.start(); // cava died (pipewire restart etc.), try again
}

void CavaMonitor::onReadyRead()
{
    m_buf += m_proc.readAllStandardOutput();

    const int last = m_buf.lastIndexOf('\n');
    if (last < 0) {
        if (m_buf.size() > 4096)
            m_buf.clear();
        return;
    }

    // only the newest complete frame matters; older ones are stale, drop them
    const int prev = m_buf.lastIndexOf('\n', last - 1);
    const QByteArray line = m_buf.mid(prev + 1, last - prev - 1);
    m_buf.remove(0, last + 1);

    parseFrame(line);
}

void CavaMonitor::parseFrame(const QByteArray &line)
{
    QList<qreal> out(m_barCount, 0.0);

    int bin = 0;
    const char *p = line.constData();
    const char *end = p + line.size();
    while (p < end) {
        int v = 0;
        bool digits = false;
        while (p < end && *p >= '0' && *p <= '9') {
            v = v * 10 + (*p - '0');
            digits = true;
            ++p;
        }
        if (digits) {
            const int idx = bin - m_skipLow;
            if (idx >= 0 && idx < m_barCount)
                out[idx] = std::clamp(double(v), 0.0, 100.0);
            ++bin;
        }
        if (p < end)
            ++p; // delimiter
    }

    if (out != m_values) {
        m_values = std::move(out);
        emit valuesChanged();
    }
}
