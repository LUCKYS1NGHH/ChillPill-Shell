#include "SpectrumBars.h"

#include <QEasingCurve>
#include <QSGGeometry>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>
#include <QtMath>
#include <algorithm>

namespace {

constexpr int kCornerSegs = 3;

struct Rgba { uchar r, g, b, a; };

Rgba premul(const QColor &c)
{
    const qreal a = c.alphaF();
    return { uchar(c.redF() * a * 255 + 0.5), uchar(c.greenF() * a * 255 + 0.5),
             uchar(c.blueF() * a * 255 + 0.5), uchar(a * 255 + 0.5) };
}

QList<qreal> toRaw(const QVariant &v)
{
    if (v.metaType() == QMetaType::fromType<QList<qreal>>())
        return v.value<QList<qreal>>();
    QList<qreal> out;
    if (v.canConvert<QVariantList>()) {
        const QVariantList l = v.toList();
        out.reserve(l.size());
        for (const QVariant &e : l)
            out.append(e.toReal());
    }
    return out;
}

inline void tri(QSGGeometry::ColoredPoint2D *&v, const Rgba &c,
                float ax, float ay, float bx, float by, float cx, float cy)
{
    (v++)->set(ax, ay, c.r, c.g, c.b, c.a);
    (v++)->set(bx, by, c.r, c.g, c.b, c.a);
    (v++)->set(cx, cy, c.r, c.g, c.b, c.a);
}

} // namespace

SpectrumBars::SpectrumBars(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, true);

    m_from = QList<qreal>(m_barCount, 0.0);
    m_to = m_from;

    m_anim.setStartValue(0.0);
    m_anim.setEndValue(1.0);
    m_anim.setEasingCurve(QEasingCurve::OutQuad);
    m_anim.setDuration(int(m_animationDuration));
    connect(&m_anim, &QVariantAnimation::valueChanged, this, [this](const QVariant &t) {
        m_t = t.toReal();
        update();
    });

    updateImplicitSize();
}

#define SB_SETTER(Name, name, T)           \
    void SpectrumBars::set##Name(T v)      \
    {                                      \
        if (m_##name == v)                 \
            return;                        \
        m_##name = v;                      \
        emit name##Changed();              \
        updateImplicitSize();              \
        update();                          \
    }

SB_SETTER(BarWidth, barWidth, qreal)
SB_SETTER(BarSpacing, barSpacing, qreal)
SB_SETTER(MaxBarHeight, maxBarHeight, qreal)
SB_SETTER(MinBarHeight, minBarHeight, qreal)
SB_SETTER(BarRadius, barRadius, qreal)
SB_SETTER(Centered, centered, bool)
#undef SB_SETTER

void SpectrumBars::setBarColor(const QColor &v)
{
    if (m_barColor == v)
        return;
    m_barColor = v;
    emit barColorChanged();
    update();
}

void SpectrumBars::setBarSecondaryColor(const QColor &v)
{
    if (m_barSecondaryColor == v)
        return;
    m_barSecondaryColor = v;
    emit barSecondaryColorChanged();
    update();
}

void SpectrumBars::setAnimationDuration(qreal v)
{
    if (qFuzzyCompare(m_animationDuration, v))
        return;
    m_animationDuration = v;
    m_anim.setDuration(qMax(0, int(v)));
    emit animationDurationChanged();
}

void SpectrumBars::setBarCount(int v)
{
    v = qMax(0, v);
    if (m_barCount == v)
        return;
    m_barCount = v;
    m_from.resize(v, 0.0);
    m_to.resize(v, 0.0);
    emit barCountChanged();
    updateImplicitSize();
    retarget();
}

void SpectrumBars::setValues(const QVariant &v)
{
    m_values = v;
    emit valuesChanged();
    retarget();
}

void SpectrumBars::updateImplicitSize()
{
    const qreal w = m_barCount > 0 ? m_barCount * m_barWidth + (m_barCount - 1) * m_barSpacing : 0;
    setImplicitSize(w, m_maxBarHeight);
}

void SpectrumBars::retarget()
{
    const QList<qreal> raw = toRaw(m_values);

    // freeze whatever is currently on screen as the new animation start
    for (int i = 0; i < m_barCount; ++i)
        m_from[i] = m_from[i] + (m_to[i] - m_from[i]) * m_t;

    for (int i = 0; i < m_barCount; ++i) {
        const qreal r = i < raw.size() ? raw[i] : 0.0;
        m_to[i] = std::clamp(r, 0.0, 100.0) / 100.0;
    }

    m_anim.stop();
    if (m_animationDuration <= 0) {
        m_from = m_to;
        m_t = 1.0;
        update();
        return;
    }
    m_t = 0.0;
    m_anim.start();
    update();
}

QSGNode *SpectrumBars::updatePaintNode(QSGNode *old, UpdatePaintNodeData *)
{
    auto *node = static_cast<QSGGeometryNode *>(old);

    const bool rounded = m_barRadius > 0.25;
    const int ptsPerBar = 4 * (kCornerSegs + 1);
    const int vertsPerBar = rounded ? ptsPerBar * 3 : 6;
    const int total = m_barCount * vertsPerBar;

    if (!node) {
        node = new QSGGeometryNode;
        auto *g = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), total);
        g->setDrawingMode(QSGGeometry::DrawTriangles);
        node->setGeometry(g);
        node->setFlag(QSGNode::OwnsGeometry);
        auto *m = new QSGVertexColorMaterial;
        m->setFlag(QSGMaterial::Blending, true);
        node->setMaterial(m);
        node->setFlag(QSGNode::OwnsMaterial);
    }

    QSGGeometry *g = node->geometry();
    if (g->vertexCount() != total)
        g->allocate(total);
    QSGGeometry::ColoredPoint2D *v = g->vertexDataAsColoredPoint2D();

    const bool twoTone = m_barSecondaryColor.alpha() > 0;
    const Rgba primary = premul(m_barColor);
    const Rgba secondary = twoTone ? premul(m_barSecondaryColor) : primary;
    const qreal H = height();

    for (int i = 0; i < m_barCount; ++i) {
        const qreal n = m_from.value(i) + (m_to.value(i) - m_from.value(i)) * m_t;
        const qreal h = std::min(H, std::max(m_minBarHeight, n * m_maxBarHeight));
        const qreal w = m_barWidth;
        const qreal x = i * (m_barWidth + m_barSpacing);
        const qreal y = m_centered ? (H - h) / 2 : H - h;
        const Rgba &c = (i % 2 == 0) ? primary : secondary;

        if (!rounded) {
            tri(v, c, x, y, x + w, y, x + w, y + h);
            tri(v, c, x, y, x + w, y + h, x, y + h);
            continue;
        }

        const qreal r = std::min({ m_barRadius, w / 2, h / 2 });
        const QPointF centers[4] = { { x + w - r, y + r }, { x + w - r, y + h - r },
                                     { x + r, y + h - r }, { x + r, y + r } };
        QPointF pts[ptsPerBar];
        int p = 0;
        for (int k = 0; k < 4; ++k) {
            const qreal a0 = -90.0 + 90.0 * k;
            for (int s = 0; s <= kCornerSegs; ++s) {
                const qreal a = qDegreesToRadians(a0 + 90.0 * s / kCornerSegs);
                pts[p++] = { centers[k].x() + r * std::cos(a), centers[k].y() + r * std::sin(a) };
            }
        }
        const float cx = x + w / 2, cy = y + h / 2;
        for (int j = 0; j < ptsPerBar; ++j) {
            const QPointF &a = pts[j];
            const QPointF &b = pts[(j + 1) % ptsPerBar];
            tri(v, c, cx, cy, a.x(), a.y(), b.x(), b.y());
        }
    }

    node->markDirty(QSGNode::DirtyGeometry | QSGNode::DirtyMaterial);
    return node;
}
