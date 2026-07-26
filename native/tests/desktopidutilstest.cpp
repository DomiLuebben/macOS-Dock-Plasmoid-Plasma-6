#include "desktopidutils.h"

#include <QTest>

class DesktopIdUtilsTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void normalizesDesktopLaunchers()
    {
        QCOMPARE(DesktopIdUtils::normalize(
                     QStringLiteral("applications:Affinity.desktop")),
                 QStringLiteral("affinity"));
    }

    void normalizesWineExecutables()
    {
        QCOMPARE(DesktopIdUtils::normalize(
                     QStringLiteral("application://affinity.exe")),
                 QStringLiteral("affinity"));
        QCOMPARE(DesktopIdUtils::normalize(
                     QStringLiteral(
                         R"(C:\Program Files\Affinity\Affinity.EXE)")),
                 QStringLiteral("affinity"));
        QCOMPARE(DesktopIdUtils::normalize(
                     QStringLiteral(
                         "applications:Affinity.exe.desktop")),
                 QStringLiteral("affinity"));
    }
};

QTEST_MAIN(DesktopIdUtilsTest)

#include "desktopidutilstest.moc"
