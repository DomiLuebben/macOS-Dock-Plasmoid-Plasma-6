#include "windowactions.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QFileInfo>

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

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"), QStringLiteral("killWindow"));
    bus.asyncCall(message);
    return true;
}

bool WindowActions::activateVirtualDesktop(int desktopNumber)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (desktopNumber <= 0 || !m_interactiveForceQuitAvailable
            || !bus.isConnected()) {
        return false;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("setCurrentDesktop"));
    message.setArguments({desktopNumber});
    bus.asyncCall(message);
    return true;
}

bool WindowActions::createVirtualDesktop(int position)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (position < 0 || !m_interactiveForceQuitAvailable
            || !bus.isConnected()) {
        return false;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/VirtualDesktopManager"),
        QStringLiteral("org.kde.KWin.VirtualDesktopManager"),
        QStringLiteral("createDesktop"));
    message.setArguments({
        QVariant::fromValue(static_cast<uint>(position)),
        QString()
    });
    bus.asyncCall(message);
    return true;
}

QString WindowActions::canonicalDirectoryUrl(const QUrl &url) const
{
    QString localPath;
    if (url.isLocalFile()) {
        localPath = url.toLocalFile();
    } else if (url.scheme().isEmpty()) {
        localPath = url.toString();
    } else {
        return {};
    }

    const QFileInfo directory(localPath);
    if (!directory.exists() || !directory.isDir()) {
        return {};
    }

    QString path = directory.canonicalFilePath();
    if (path.isEmpty()) {
        path = directory.absoluteFilePath();
    }
    return QUrl::fromLocalFile(path).toString();
}

void WindowActions::shutdown()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("org.kde.Shutdown"),
            QStringLiteral("/Shutdown"),
            QStringLiteral("org.kde.Shutdown"),
            QStringLiteral("logoutAndShutdown"));
        bus.asyncCall(message);
    }
}

void WindowActions::reboot()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("org.kde.Shutdown"),
            QStringLiteral("/Shutdown"),
            QStringLiteral("org.kde.Shutdown"),
            QStringLiteral("logoutAndReboot"));
        bus.asyncCall(message);
    }
}

void WindowActions::logout()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("org.kde.Shutdown"),
            QStringLiteral("/Shutdown"),
            QStringLiteral("org.kde.Shutdown"),
            QStringLiteral("logout"));
        bus.asyncCall(message);
    }
}

void WindowActions::suspend()
{
    const QDBusConnection bus = QDBusConnection::systemBus();
    if (bus.isConnected()) {
        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("org.freedesktop.login1"),
            QStringLiteral("/org/freedesktop/login1"),
            QStringLiteral("org.freedesktop.login1.Manager"),
            QStringLiteral("Suspend"));
        message.setArguments({true});
        bus.asyncCall(message);
    }
}

void WindowActions::lockSession()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (bus.isConnected()) {
        QDBusMessage message = QDBusMessage::createMethodCall(
            QStringLiteral("org.freedesktop.ScreenSaver"),
            QStringLiteral("/ScreenSaver"),
            QStringLiteral("org.freedesktop.ScreenSaver"),
            QStringLiteral("Lock"));
        bus.asyncCall(message);
    }
}

void WindowActions::setInteractiveForceQuitAvailable(bool available)
{
    if (m_interactiveForceQuitAvailable == available) {
        return;
    }

    m_interactiveForceQuitAvailable = available;
    Q_EMIT interactiveForceQuitAvailableChanged();
}
