#pragma once

#include <QColor>
#include <QList>
#include <QQuickItem>
#include <QVariant>
#include <QVariantAnimation>
#include <QtQml/qqmlregistration.h>

// Scene-graph spectrum renderer. One geometry node, one draw call, no
// per-bar QML items or bindings. Values are 0-100 per bar (low -> high freq).
class SpectrumBars : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int barCount READ barCount WRITE setBarCount NOTIFY barCountChanged)
    Q_PROPERTY(qreal barWidth READ barWidth WRITE setBarWidth NOTIFY barWidthChanged)
    Q_PROPERTY(qreal barSpacing READ barSpacing WRITE setBarSpacing NOTIFY barSpacingChanged)
    Q_PROPERTY(qreal maxBarHeight READ maxBarHeight WRITE setMaxBarHeight NOTIFY maxBarHeightChanged)
    Q_PROPERTY(qreal minBarHeight READ minBarHeight WRITE setMinBarHeight NOTIFY minBarHeightChanged)
    Q_PROPERTY(qreal barRadius READ barRadius WRITE setBarRadius NOTIFY barRadiusChanged)
    Q_PROPERTY(QColor barColor READ barColor WRITE setBarColor NOTIFY barColorChanged)
    // fully transparent (alpha 0) = unused; otherwise odd bars use it
    Q_PROPERTY(QColor barSecondaryColor READ barSecondaryColor WRITE setBarSecondaryColor NOTIFY barSecondaryColorChanged)
    Q_PROPERTY(bool centered READ centered WRITE setCentered NOTIFY centeredChanged)
    Q_PROPERTY(qreal animationDuration READ animationDuration WRITE setAnimationDuration NOTIFY animationDurationChanged)
    Q_PROPERTY(QVariant values READ values WRITE setValues NOTIFY valuesChanged)

public:
    explicit SpectrumBars(QQuickItem *parent = nullptr);

    int barCount() const { return m_barCount; }
    qreal barWidth() const { return m_barWidth; }
    qreal barSpacing() const { return m_barSpacing; }
    qreal maxBarHeight() const { return m_maxBarHeight; }
    qreal minBarHeight() const { return m_minBarHeight; }
    qreal barRadius() const { return m_barRadius; }
    QColor barColor() const { return m_barColor; }
    QColor barSecondaryColor() const { return m_barSecondaryColor; }
    bool centered() const { return m_centered; }
    qreal animationDuration() const { return m_animationDuration; }
    QVariant values() const { return m_values; }

    void setBarCount(int v);
    void setBarWidth(qreal v);
    void setBarSpacing(qreal v);
    void setMaxBarHeight(qreal v);
    void setMinBarHeight(qreal v);
    void setBarRadius(qreal v);
    void setBarColor(const QColor &v);
    void setBarSecondaryColor(const QColor &v);
    void setCentered(bool v);
    void setAnimationDuration(qreal v);
    void setValues(const QVariant &v);

signals:
    void barCountChanged();
    void barWidthChanged();
    void barSpacingChanged();
    void maxBarHeightChanged();
    void minBarHeightChanged();
    void barRadiusChanged();
    void barColorChanged();
    void barSecondaryColorChanged();
    void centeredChanged();
    void animationDurationChanged();
    void valuesChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;

private:
    void updateImplicitSize();
    void retarget();

    int m_barCount = 16;
    qreal m_barWidth = 2.5;
    qreal m_barSpacing = 2;
    qreal m_maxBarHeight = 14;
    qreal m_minBarHeight = 3;
    qreal m_barRadius = 1.5;
    QColor m_barColor = Qt::white;
    QColor m_barSecondaryColor = Qt::transparent;
    bool m_centered = false;
    qreal m_animationDuration = 70;
    QVariant m_values;

    // normalized 0..1 per bar; drawn value = from + (to - from) * m_t
    QList<qreal> m_from;
    QList<qreal> m_to;
    qreal m_t = 1.0;
    QVariantAnimation m_anim;
};
