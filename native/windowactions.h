#pragma once

#include <QObject>
#include <QString>
#include <QUrl>

class QDBusServiceWatcher;

class WindowActions : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool interactiveForceQuitAvailable READ interactiveForceQuitAvailable NOTIFY interactiveForceQuitAvailableChanged)

public:
    explicit WindowActions(QObject *parent = nullptr);

    bool interactiveForceQuitAvailable() const;

    /**
     * Starts KWin's native interactive window killer. KWin changes the cursor
     * to a target; the user then selects the unresponsive window or presses
     * Escape to cancel. This deliberately avoids killing TaskManager::AppPid,
     * which is documented as unsafe for destructive actions on Wayland.
     */
    Q_INVOKABLE bool startInteractiveForceQuit();

    /** Activates a KWin virtual desktop by its one-based position. */
    Q_INVOKABLE bool activateVirtualDesktop(int desktopNumber);

    /** Creates a virtual desktop at the zero-based position. */
    Q_INVOKABLE bool createVirtualDesktop(int position);

    /** Returns a canonical file URL for a local directory, or an empty string. */
    Q_INVOKABLE QString canonicalDirectoryUrl(const QUrl &url) const;

Q_SIGNALS:
    void interactiveForceQuitAvailableChanged();

private:
    void setInteractiveForceQuitAvailable(bool available);

    QDBusServiceWatcher *m_serviceWatcher = nullptr;
    bool m_interactiveForceQuitAvailable = false;
};
