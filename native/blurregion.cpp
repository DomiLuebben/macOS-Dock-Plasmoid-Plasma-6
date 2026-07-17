#include "blurregion.h"

#include <KWindowEffects>

#include <QEvent>
#include <QPainterPath>
#include <QPlatformSurfaceEvent>
#include <QRegion>
#include <QTimer>
#include <QWindow>

#include <algorithm>

BlurRegion::BlurRegion(QObject *parent)
    : QObject(parent)
{
}

BlurRegion::~BlurRegion()
{
    if (m_window) {
        disableFor(m_window);
        m_window->removeEventFilter(this);
    }
}

QWindow *BlurRegion::window() const
{
    return m_window;
}

void BlurRegion::setWindow(QWindow *window)
{
    if (m_window == window) {
        return;
    }

    if (m_window) {
        disableFor(m_window);
        m_window->removeEventFilter(this);
        disconnect(m_window, nullptr, this, nullptr);
    }

    m_window = window;

    if (m_window) {
        m_window->installEventFilter(this);
        connect(m_window, &QWindow::visibleChanged, this,
                [this](bool visible) {
                    if (visible) {
                        scheduleApply();
                    }
                });
        connect(m_window, &QWindow::widthChanged,
                this, &BlurRegion::scheduleApply);
        connect(m_window, &QWindow::heightChanged,
                this, &BlurRegion::scheduleApply);
    }

    Q_EMIT windowChanged();
    scheduleApply();
}

QRectF BlurRegion::region() const
{
    return m_region;
}

void BlurRegion::setRegion(const QRectF &region)
{
    if (m_region == region) {
        return;
    }

    m_region = region;
    Q_EMIT regionChanged();
    scheduleApply();
}

qreal BlurRegion::radius() const
{
    return m_radius;
}

void BlurRegion::setRadius(qreal radius)
{
    radius = std::max<qreal>(0.0, radius);
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }

    m_radius = radius;
    Q_EMIT radiusChanged();
    scheduleApply();
}

bool BlurRegion::enabled() const
{
    return m_enabled;
}

void BlurRegion::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }

    m_enabled = enabled;
    Q_EMIT enabledChanged();
    scheduleApply();
}

void BlurRegion::apply()
{
    m_applyScheduled = false;

    if (!m_window) {
        return;
    }

    // Applying an effect before a layer-shell surface becomes visible can
    // race its native surface creation. visibleChanged schedules a fresh pass.
    if (!m_window->isVisible()) {
        return;
    }

    if (!m_enabled || m_region.isEmpty()) {
        disableFor(m_window);
        return;
    }

    const QRect windowBounds(0, 0, m_window->width(), m_window->height());
    QRect blurRect = m_region.toAlignedRect();
    blurRect = blurRect.intersected(windowBounds);

    if (blurRect.isEmpty()) {
        disableFor(m_window);
        return;
    }

    const qreal effectiveRadius = std::min<qreal>(
        m_radius, std::min(blurRect.width(), blurRect.height()) / 2.0);

    QRegion blurRegion;
    if (effectiveRadius > 0.0) {
        QPainterPath path;
        path.addRoundedRect(QRectF(blurRect), effectiveRadius, effectiveRadius);
        blurRegion = QRegion(path.toFillPolygon().toPolygon(), Qt::WindingFill);
    } else {
        blurRegion = QRegion(blurRect);
    }

    KWindowEffects::enableBlurBehind(m_window, true, blurRegion);
}

bool BlurRegion::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window
            && event->type() == QEvent::PlatformSurface) {
        const auto *surfaceEvent = static_cast<QPlatformSurfaceEvent *>(event);
        if (surfaceEvent->surfaceEventType()
                == QPlatformSurfaceEvent::SurfaceCreated) {
            scheduleApply();
        }
    }

    return QObject::eventFilter(watched, event);
}

void BlurRegion::scheduleApply()
{
    if (m_applyScheduled) {
        return;
    }

    m_applyScheduled = true;
    QTimer::singleShot(0, this, &BlurRegion::apply);
}

void BlurRegion::disableFor(QWindow *window)
{
    KWindowEffects::enableBlurBehind(window, false);
}
