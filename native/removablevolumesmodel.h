#ifndef REMOVABLEVOLUMESMODEL_H
#define REMOVABLEVOLUMESMODEL_H

#include <QAbstractListModel>
#include <QUrl>
#include <QVariant>
#include <QList>
#include <QString>
#include <QSet>

#include <Solid/SolidNamespace>

class RemovableVolumesModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool openInNewTab READ openInNewTab WRITE setOpenInNewTab NOTIFY openInNewTabChanged)

public:
    enum Roles {
        UdiRole = Qt::UserRole + 1,
        DisplayNameRole,
        IconNameRole,
        MountUrlRole,
        KindRole,
        MountedRole,
        BusyRole,
        OperationRole,
        CanOpenRole,
        CanRemoveRole,
        ErrorTextRole
    };
    Q_ENUM(Roles)

    /**
     * Wie ein Datentraeger geoeffnet wird.
     *
     * Die drei Werte sind bewusst NICHT als `bool` gefuehrt. Ein Wahrheitswert
     * kennt nur „Tab" und „Fenster" und zwingt damit jede Voreinstellung in
     * eine Dolphin-spezifische Betriebsart. Genau daran ist 1.14.0 gescheitert:
     * `openRemovableVolumesInNewTab = false` (die Voreinstellung) landete im
     * Zweig `dolphin --new-window` und ersetzte damit fuer JEDEN Nutzer den
     * eingestellten Dateimanager durch Dolphin.
     */
    enum class OpenMode {
        /// `QDesktopServices` — der im System eingestellte Dateimanager.
        DefaultApplication,
        /// Neuer Tab in einem bereits laufenden Dolphin-Fenster.
        DolphinTab,
        /// Ausdruecklich ein eigenes Fenster (`dolphin --new-window`).
        DolphinWindow,
    };
    Q_ENUM(OpenMode)

    struct VolumeItem {
        QString udi;
        QString displayName;
        QString iconName;
        QUrl mountUrl;
        QString kind; // "filesystem" or "optical"
        bool mounted{true};
        bool busy{false};
        QString operation{"idle"}; // "idle", "unmounting", "ejecting"
        bool canOpen{true};
        bool canRemove{true};
        bool openOnMount{false};
        OpenMode openModeOnMount{OpenMode::DefaultApplication};
        QString errorText;
    };

    explicit RemovableVolumesModel(QObject *parent = nullptr);
    ~RemovableVolumesModel() override = default;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;

    bool openInNewTab() const;
    void setOpenInNewTab(bool openInNewTab);

    /**
     * Betriebsart der Standardaktion (Klick auf das Symbol, erster Menueintrag).
     * Ist die Tab-Option aus, bleibt es beim Dateimanager des Systems — die
     * Standardaktion darf keine Anwendung erzwingen.
     */
    OpenMode defaultOpenMode() const;

    /**
     * Exakter Abgleich eines D-Bus-Dienstnamens gegen Dolphin.
     * Oeffentlich, weil er die einzige Stelle ist, an der wir einem fremden
     * Prozess einen Pfad schicken — und damit testbar sein muss.
     */
    static bool isDolphinService(const QString &service);

    Q_INVOKABLE void open(const QString &udi);
    /// Ausdrueckliche Wahl aus dem Kontextmenue: Tab oder eigenes Fenster.
    Q_INVOKABLE void open(const QString &udi, bool inNewTab);
    Q_INVOKABLE void mount(const QString &udi);
    Q_INVOKABLE void mount(const QString &udi, bool inNewTab);
    Q_INVOKABLE void remove(const QString &udi);

signals:
    void countChanged();
    void openInNewTabChanged();
    void operationFailed(const QString &udi, const QString &message);
    void operationSucceeded(const QString &udi);

private slots:
    void onDeviceAdded(const QString &udi);
    void onDeviceRemoved(const QString &udi);
    void onAccessibilityChanged(bool accessible, const QString &udi);
    void onTeardownRequested(const QString &udi);
    void onSetupDone(Solid::ErrorType error, const QVariant &errorData, const QString &udi);
    void onTeardownDone(Solid::ErrorType error, const QVariant &errorData, const QString &udi);
    void onEjectDone(Solid::ErrorType error, const QVariant &errorData, const QString &udi);

private:
    void refreshModel();
    bool isCandidateDevice(const QString &udi, VolumeItem &itemOut, bool requireMounted = true);
    int findRowByUdi(const QString &udi) const;
    void connectDeviceSignals(const QString &udi);
    void reportError(const QString &udi, const QString &message);
    void open(const QString &udi, OpenMode mode);
    void mount(const QString &udi, OpenMode mode);
    void openWhenReady(const QString &udi, OpenMode mode, int retries = 10);
    static bool openInDolphinTab(const QUrl &url);
    static void openUrl(const QUrl &url, OpenMode mode);

    QList<VolumeItem> m_items;
    QSet<QString> m_watchedUdis;
    bool m_openInNewTab = false;
};

#endif // REMOVABLEVOLUMESMODEL_H
