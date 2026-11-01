#pragma once
// Índice local Nimbus (F6-T02): fast-path <50ms sin KRunner.
// Qt Core (+Gui para iconos por nombre, +DBus solo para klipper).
// KRunner queda como fallback (Tab / "Buscar en KRunner").
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <atomic>

struct LocalApp {
    QString id;       // fichero .desktop
    QString name;
    QString exec;     // Exec limpio (sin %codes)
    QString iconName;
    QString keywords; // Keywords + Categories para fuzzy
    bool isSetting = false;
};

struct LocalFile {
    QString name;
    QString path;
    bool recent = false;
};

class NimbusIndex : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList localMatches READ localMatches NOTIFY localMatchesChanged)
    Q_PROPERTY(qint64 localLatencyMs READ localLatencyMs NOTIFY localMatchesChanged)
    Q_PROPERTY(bool indexReady READ indexReady NOTIFY indexReadyChanged)
    Q_PROPERTY(bool krunnerFallback READ krunnerFallback NOTIFY krunnerFallbackChanged)
    Q_PROPERTY(QString searchEngine READ searchEngine CONSTANT)
public:
    explicit NimbusIndex(QObject *parent = nullptr);
    ~NimbusIndex() override;

    QVariantList localMatches() const { return m_matches; }
    qint64 localLatencyMs() const { return m_latency; }
    bool indexReady() const { return m_ready; }
    bool krunnerFallback() const { return m_krunnerFallback; }
    QString searchEngine() const { return m_searchEngine; }

    // Búsqueda síncrona en memoria (índice ya construido): objetivo <50ms.
    Q_INVOKABLE void searchLocal(const QString &term, const QString &tab = QString());
    // Reescaneo: apps/settings en hilo de llamada (rápido), ficheros en worker.
    Q_INVOKABLE void rescan();
    // Acciones sobre resultado local: "open" | "copy" | "reveal".
    Q_INVOKABLE bool activateLocal(int index, const QString &action = QStringLiteral("open"));
    Q_INVOKABLE void recordUse(const QString &id);
    // El usuario pide KRunner (Tab o botón): QML llama a backend.search().
    Q_INVOKABLE void requestKRunner();
    Q_INVOKABLE void clearKRunnerFallback();
    // Portapapeles (F6-T06): klipper DBus → history2.lst → wl-paste.
    // `filter` vacío = historial completo (máx 20).
    Q_INVOKABLE QVariantList clipboardEntries(const QString &filter = QString());
    // Copia texto al portapapeles (Pegar/Copiar cierra el overlay en QML).
    Q_INVOKABLE bool copyToClipboard(const QString &text);
    // Última latencia de clipboardEntries/emojiList (síncronos, sin señal).
    Q_INVOKABLE qint64 lastClipLatency() const { return m_latency; }
    // Emoji (F6-T06): datos propios, sin assets externos; i18n vía qsTr en QML.
    Q_INVOKABLE QVariantList emojiList(const QString &term,
                                       const QString &category = QString());
    Q_INVOKABLE QStringList emojiCategories();
    Q_INVOKABLE void recordEmoji(const QString &glyph);
    Q_INVOKABLE QVariantList recentEmojis();

    // Unit-testeables (sin FS ni DBus).
    static int fuzzyScore(const QString &candidate, const QString &query);
    static double evalCalc(const QString &expr, bool &ok);
    static bool isCalcQuery(const QString &term);
    static bool parseDesktopFile(const QString &path, LocalApp &out);
    static QString cleanExec(const QString &exec);
    static QString webUrl(const QString &term);
    // Entrada de portapapeles (truncado <16k, sin formato): testeable sin DBus.
    static QVariantMap clipEntry(const QString &text, int i);
    // Parser tolerante de history2.lst de klipper (\n y \0, sin vacíos ni
    // duplicados): fallback sin DBus. Testeable sin FS.
    static QStringList parseKlipperHistoryFile(const QString &data);
    // Entrada de emoji para QML (glyph conocido de la tabla propia).
    static QVariantMap emojiToMap(const QString &glyph, const QString &name,
                                  const QString &category, const QString &kw, int i);
    // Escaneo de raíces de ficheros (fixture-testeable; el worker lo usa).
    static QList<LocalFile> scanRoots(const QStringList &roots, int maxFiles = 4000);

Q_SIGNALS:
    void localMatchesChanged();
    void indexReadyChanged();
    void krunnerFallbackChanged();

private:
    void scanApps();
    void scanFilesAsync();
    void loadFreq();
    void saveFreq();
    void loadEmojiRecents();
    void saveEmojiRecents();
    QString emojiRecentsPath() const;
    void setReady(bool v);
    void setKRunnerFallback(bool v);
    QVariantMap appToMap(const LocalApp &a, int rank, int qi) const;
    QVariantMap fileToMap(const LocalFile &f, int rank, int qi) const;

    QList<LocalApp> m_apps;
    QList<LocalFile> m_files; // caché de ficheros
    QVariantList m_matches;
    QHash<QString, int> m_freq;
    QString m_freqPath;
    QStringList m_emojiRecents; // glifos, más reciente primero (máx 12)
    bool m_emojiLoaded = false;
    QString m_searchEngine = QStringLiteral("https://duckduckgo.com/?q=%1");
    QString m_lastTab;
    qint64 m_latency = -1;
    bool m_ready = false;
    bool m_krunnerFallback = false;
    std::atomic<bool> m_scanRunning{false};
};
