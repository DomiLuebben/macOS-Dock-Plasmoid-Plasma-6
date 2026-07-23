#pragma once

#include <QFileInfo>
#include <QString>
#include <QUrl>

namespace DesktopIdUtils
{
inline QString normalize(const QString &rawId)
{
    QString desktopId = rawId.trimmed();
    const qsizetype queryIndex = desktopId.indexOf(QLatin1Char('?'));
    if (queryIndex >= 0) {
        desktopId.truncate(queryIndex);
    }

    if (desktopId.startsWith(QLatin1String("application://"))) {
        desktopId.remove(0, 14);
    } else if (desktopId.startsWith(QLatin1String("applications:"))) {
        desktopId.remove(0, 13);
    } else {
        const QUrl url(desktopId);
        if (url.isLocalFile()) {
            desktopId = QFileInfo(url.toLocalFile()).fileName();
        }
    }

    desktopId = QUrl::fromPercentEncoding(desktopId.toUtf8());
    desktopId.replace(QLatin1Char('\\'), QLatin1Char('/'));
    const qsizetype slashIndex = desktopId.lastIndexOf(QLatin1Char('/'));
    if (slashIndex >= 0) {
        desktopId.remove(0, slashIndex + 1);
    }
    if (desktopId.endsWith(QLatin1String(".desktop"), Qt::CaseInsensitive)) {
        desktopId.chop(8);
    }
    return desktopId.toLower();
}
}
