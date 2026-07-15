#pragma once

#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QWindow>

class QEvent;

class BlurRegion : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(QRectF region READ region WRITE setRegion NOTIFY regionChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit BlurRegion(QObject *parent = nullptr);
    ~BlurRegion() override;

    QWindow *window() const;
    void setWindow(QWindow *window);

    QRectF region() const;
    void setRegion(const QRectF &region);

    qreal radius() const;
    void setRadius(qreal radius);

    bool enabled() const;
    void setEnabled(bool enabled);

    Q_INVOKABLE void apply();

Q_SIGNALS:
    void windowChanged();
    void regionChanged();
    void radiusChanged();
    void enabledChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void scheduleApply();
    void disableFor(QWindow *window);

    QPointer<QWindow> m_window;
    QRectF m_region;
    qreal m_radius = 0.0;
    bool m_enabled = true;
    bool m_applyScheduled = false;
};
