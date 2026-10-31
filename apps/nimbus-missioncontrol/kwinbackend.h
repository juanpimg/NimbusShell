#pragma once
// KWinBackend — puente QML <-> KWin scripting/DBus (F7-T01/T02).
// Sin KF obligatorio: solo Qt6 DBus. Thumbnails vía ScreenShot2 si
// responde; si no, fallback icono+título (hasThumbnails=false).
#include <QObject>
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
    void setExposeActiveAppOnly(bool v);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void activateWindow(const QString &winId);
    Q_INVOKABLE void moveWindowToDesktop(const QString &winId, const QString &deskId);
    Q_INVOKABLE void setCurrentDesktopById(const QString &deskId);
    Q_INVOKABLE void setCurrentDesktopByIndex(int idx);
    Q_INVOKABLE void toggleExpose();
    Q_INVOKABLE void loadDemo();
    // Test: activa la primera ventana con título y devuelve su caption.
    Q_INVOKABLE QString activateFirst();

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

private:
    void readDesktops();
    void requestWindowsViaScript();
    void runOneshotScript(const QString &js, const QString &tag);
    void probeScreenshots();
    void setError(const QString &e);

    bool m_demo = false;
    QVariantList m_desktops;
    QVariantList m_windows;
    int m_currentDesktop = 1;
    QString m_currentApp;
    bool m_exposeOnly = false;
    bool m_hasThumbnails = false;
    int m_latencyMs = -1;
    QString m_lastError;
    qint64 m_refreshT0 = 0;
    int m_dumpSeq = 0;
};
