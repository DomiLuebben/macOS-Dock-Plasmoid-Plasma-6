#include "windowactions.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDebug>
#include <QFileInfo>
#include <QVariant>

namespace
{
constexpr int virtualDesktopRequestTimeoutMs = 5000;
}

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
            this, [this]() { setKWinAvailable(true); });
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered,
            this, [this]() { setKWinAvailable(false); });

    if (bus.isConnected() && bus.interface()) {
        const QDBusReply<bool> registered =
            bus.interface()->isServiceRegistered(QStringLiteral("org.kde.KWin"));
        if (registered.isValid()) {
            m_kwinAvailable = registered.value();
        }
    }
}

bool WindowActions::interactiveForceQuitAvailable() const
{
    return m_kwinAvailable;
}

bool WindowActions::startInteractiveForceQuit()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!m_kwinAvailable || !bus.isConnected()) {
        return false;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"), QStringLiteral("killWindow"));
    bus.asyncCall(message);
    return true;
}

void WindowActions::requestVirtualDesktopActivation(int desktopNumber)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (desktopNumber <= 0 || !m_kwinAvailable
            || !bus.isConnected()) {
        return;
    }

    QDBusMessage message = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("setCurrentDesktop"));
    message.setArguments({desktopNumber});
    auto *watcher = new QDBusPendingCallWatcher(
        bus.asyncCall(message, virtualDesktopRequestTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [watcher]() {
                const QDBusPendingReply<bool> reply = *watcher;
                if (reply.isError()) {
                    qWarning() << "Failed to activate virtual desktop:"
                               << reply.error().message();
                } else if (!reply.value()) {
                    qWarning() << "KWin rejected virtual desktop activation";
                }
                watcher->deleteLater();
            });
}

bool WindowActions::createVirtualDesktop(int position)
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (position < 0 || m_desktopCreationPending || !m_kwinAvailable
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
    m_desktopCreationPending = true;
    auto *watcher = new QDBusPendingCallWatcher(
        bus.asyncCall(message, virtualDesktopRequestTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, watcher]() {
                const QDBusPendingReply<> reply = *watcher;
                const bool succeeded = !reply.isError();
                if (!succeeded) {
                    qWarning() << "Failed to create virtual desktop:"
                               << reply.error().message();
                }
                m_desktopCreationPending = false;
                watcher->deleteLater();
                Q_EMIT virtualDesktopCreationFinished(succeeded);
            });
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

void WindowActions::setKWinAvailable(bool available)
{
    if (m_kwinAvailable == available) {
        return;
    }

    m_kwinAvailable = available;
    Q_EMIT interactiveForceQuitAvailableChanged();
}
