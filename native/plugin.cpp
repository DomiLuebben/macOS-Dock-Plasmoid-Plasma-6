#include "blurregion.h"
#include "folderwatcher.h"
#include "windowactions.h"
#include "installedappsmodel.h"
#include "launchermonitor.h"
#include "launcherprogressmonitor.h"
#include "kdeconnectsharemonitor.h"
#include "opendocumentlocator.h"
#include "plugininfo.h"
#include "removablevolumesmodel.h"

#include <QQmlEngine>
#include <QQmlExtensionPlugin>

class MacOSDockEffectsPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<BlurRegion>(uri, 1, 0, "BlurRegion");
        qmlRegisterType<FolderWatcher>(uri, 1, 0, "FolderWatcher");
        qmlRegisterType<WindowActions>(uri, 1, 0, "WindowActions");
        qmlRegisterType<InstalledAppsModel>(uri, 1, 0, "InstalledAppsModel");
        qmlRegisterType<LauncherMonitor>(uri, 1, 0, "LauncherMonitor");
        qmlRegisterType<LauncherProgressMonitor>(uri, 1, 0, "LauncherProgressMonitor");
        qmlRegisterType<KdeConnectShareMonitor>(uri, 1, 0, "KdeConnectShareMonitor");
        qmlRegisterType<RemovableVolumesModel>(uri, 1, 0, "RemovableVolumesModel");
        qmlRegisterType<OpenDocumentLocator>(uri, 1, 0, "OpenDocumentLocator");
        qmlRegisterType<PluginInfo>(uri, 1, 0, "PluginInfo");
    }
};

#include "plugin.moc"
