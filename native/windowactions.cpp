#include "windowactions.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusServiceWatcher>

WindowActions::WindowActions(QObject *parent)
    : QObject(parent)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    m_serviceWatcher = new QDBusServiceWatcher(
        QStringLiteral("org.kde.KWin"), bus,
        QDBusServiceWatcher::WatchForRegistration
            | QDBusServiceWatcher::WatchForUnregistration,
        this);

    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceRegistered,
            this, [this]() { setInteractiveForceQuitAvailable(true); });
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered,
            this, [this]() { setInteractiveForceQuitAvailable(false); });

    if (bus.isConnected() && bus.interface()) {
        const QDBusReply<bool> registered =
            bus.interface()->isServiceRegistered(QStringLiteral("org.kde.KWin"));
        if (registered.isValid()) {
            m_interactiveForceQuitAvailable = registered.value();
        }
    }
}

bool WindowActions::interactiveForceQuitAvailable() const
{
    return m_interactiveForceQuitAvailable;
}

bool WindowActions::startInteractiveForceQuit()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!m_interactiveForceQuitAvailable || !bus.isConnected()) {
        return false;
    }

    const QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"), QStringLiteral("killWindow"));
    bus.asyncCall(message);
    return true;
}

void WindowActions::setInteractiveForceQuitAvailable(bool available)
{
    if (m_interactiveForceQuitAvailable == available) {
        return;
    }

    m_interactiveForceQuitAvailable = available;
    Q_EMIT interactiveForceQuitAvailableChanged();
}
