#pragma once
// KWinBackend — puente QML <-> KWin scripting/DBus (F7 R-MC-CUSTOM).
// Sin KF obligatorio: solo Qt6 DBus. Thumbnails vía ScreenShot2 si
// responde (F7-T04); si no, fallback icono+título (hasThumbnails=false).
#include <QObject>
#include <QStringList>
#include <QVariantList>

class KWinBackend : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.nimbus.MissionControl")
    Q_PROPERTY(QVariantList desktops READ desktops NOTIFY desktopsChanged)
    Q_PROPERTY(QVariantList windows READ windows NOTIFY windowsChanged)
    Q_PROPERTY(int currentDesktop READ currentDesktop NOTIFY desktopsChanged)
    Q_PROPERTY(QString currentApp READ currentApp NOTIFY windowsChanged)
    Q_PROPERTY(bool exposeActiveAppOnly READ exposeActiveAppOnly WRITE setExposeActiveAppOnly NOTIFY exposeChanged)
    Q_PROPERTY(bool hasThumbnails READ hasThumbnails NOTIFY windowsChanged)
    Q_PROPERTY(int openLatencyMs READ openLatencyMs NOTIFY statsChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY statsChanged)
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion NOTIFY motionChanged)
    Q_PROPERTY(int introKey READ introKey NOTIFY introChanged)
    Q_PROPERTY(QString workspaceThumb READ workspaceThumb NOTIFY windowsChanged)
public:
    explicit KWinBackend(bool demo, QObject *parent = nullptr);

    QVariantList desktops() const { return m_desktops; }
    QVariantList windows() const { return m_windows; }
    int currentDesktop() const { return m_currentDesktop; }
    QString currentApp() const { return m_currentApp; }
    bool exposeActiveAppOnly() const { return m_exposeOnly; }
    bool hasThumbnails() const { return m_hasThumbnails; }
    int openLatencyMs() const { return m_latencyMs; }
    QString lastError() const { return m_lastError; }
    bool reduceMotion() const { return m_reduceMotion; }
    int introKey() const { return m_introKey; }
    QString workspaceThumb() const { return m_workspaceThumb; }
    void setExposeActiveAppOnly(bool v);
    void setReduceMotion(bool v);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void activateWindow(const QString &winId);
    Q_INVOKABLE void moveWindowToDesktop(const QString &winId, const QString &deskId);
    Q_INVOKABLE void moveWindowToDesktopAtCursor(const QString &winId);
    Q_INVOKABLE void setCurrentDesktopById(const QString &deskId);
    Q_INVOKABLE void setCurrentDesktopByIndex(int idx);
    Q_INVOKABLE void toggleExpose();
    Q_INVOKABLE void loadDemo();
    // Test: activa la primera ventana con título y devuelve su caption.
    Q_INVOKABLE QString activateFirst();
    // F7-T01 Spaces: crea "Escritorio N" real; garantiza n al arrancar.
    Q_INVOKABLE void createSpace();
    Q_INVOKABLE void ensureSpaces(int n);
    // F7-T05 test: mueve la 1ª ventana al Space nº idx (1-based).
    Q_INVOKABLE QString moveFirstTo(int deskIndex);
    // F7-T04: intenta thumbs ScreenShot2 (workspace + hasta 10 ventanas).
    Q_INVOKABLE void requestThumbs();
    Q_INVOKABLE QString thumbLog();
    // F7-T06: re-lanza la intro (para medir fps durante la animación).
    Q_INVOKABLE void replayIntro();
    // F7-T07: Show Desktop passthrough.
    Q_INVOKABLE void showDesktop(bool show);

public Q_SLOTS:
    // Callback del helper KWin (callDBus ... pushState <json>).
    // JSON: {desktops:[{id,name,index}], current:"<id>", windows:[...]}.
    void pushState(const QString &json);
    void pushWindows(const QString &json);

Q_SIGNALS:
    void desktopsChanged();
    void windowsChanged();
    void exposeChanged();
    void statsChanged();
    void motionChanged();
    void introChanged();

private:
    void readDesktops();
    void requestWindowsViaScript();
    void runOneshotScript(const QString &js, const QString &tag);
    void probeScreenshots();
    void setError(const QString &e);
    void setWindowThumb(const QString &winId, const QString &url);
    void nextThumb(); // cadena de capturas ScreenShot2 (F7-T04)
    // Captura a outPath (convierte raw BGRA→PNG si el reply trae
    // width/height). Devuelve "" ok o el error exacto (para evidencia).
    QString captureTo(const QString &method, const QVariantList &leadArgs,
                      const QString &outPath, const QString &label);
    static int sizeClassFor(int w, int h);

    bool m_demo = false;
    bool m_spacesEnsured = false;
    QVariantList m_desktops;
    QVariantList m_windows;
    bool m_reduceMotion = false;
    int m_introKey = 0;
    QString m_workspaceThumb;
    QStringList m_thumbLog;
    int m_thumbIdx = -1; // -1 idle, 0 = workspace, 1..N ventanas
    int m_thumbCount = 0;
    QString m_thumbDir;
    int m_currentDesktop = 1;
    QString m_currentApp;
    bool m_exposeOnly = false;
    bool m_hasThumbnails = false;
    int m_latencyMs = -1;
    QString m_lastError;
    qint64 m_refreshT0 = 0;
    int m_dumpSeq = 0;
};
