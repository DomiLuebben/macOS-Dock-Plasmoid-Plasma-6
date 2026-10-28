#pragma once

#include <QObject>

// Reports which native API this build of the plugin offers, so the QML can tell
// whether it runs against a plugin it understands.
//
// A running plasmashell keeps the plugin it loaded first in memory, while QML
// files are read from disk when first needed. After an in-place update the
// shell can therefore run new QML against the old plugin, which is how a
// reinstall under a live shell goes wrong. Bump kApiVersion whenever the QML
// starts to depend on something new in the native types.
//
//   1  progress rings (LauncherProgressMonitor::progressUpdated)
//   2  unread counts (LauncherProgressMonitor::countUpdated), PluginInfo itself
//   3  InstalledAppsModel (the "Add Apps" picker)
class PluginInfo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int apiVersion READ apiVersion CONSTANT)

public:
    static constexpr int kApiVersion = 3;

    explicit PluginInfo(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    int apiVersion() const
    {
        return kApiVersion;
    }
};
