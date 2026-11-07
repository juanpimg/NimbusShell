// welcomebackend.h — estado del wizard F9-T02 (contrato §2 tokens, R-APPLE).
// Persistencia: ~/.config/nimbus-welcome.ini (QSettings IniFormat).
// En test (NIMBUS_WELCOME_SIM=1) todo es simulado: no toca el sistema.
#pragma once
#include <QObject>
#include <QPointer>
#include <QSettings>
#include <QStringList>

class QProcess;

class WelcomeBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(int step READ step WRITE setStep NOTIFY stepChanged)
    Q_PROPERTY(bool completed READ completed NOTIFY completedChanged)
    Q_PROPERTY(QString userName READ userName WRITE setUserName NOTIFY userNameChanged)
    Q_PROPERTY(QString avatarPath READ avatarPath WRITE setAvatarPath NOTIFY avatarPathChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString appearance READ appearance WRITE setAppearance NOTIFY appearanceChanged)
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY accentChanged)
    Q_PROPERTY(QString layout READ layout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(QStringList wifiNetworks READ wifiNetworks NOTIFY wifiNetworksChanged)
    Q_PROPERTY(QString wifiStatus READ wifiStatus NOTIFY wifiStatusChanged)
    Q_PROPERTY(QStringList selectedApps READ selectedApps NOTIFY selectedAppsChanged)
    Q_PROPERTY(bool isInstalling READ isInstalling NOTIFY isInstallingChanged)
    Q_PROPERTY(int installProgress READ installProgress NOTIFY installProgressChanged)
    Q_PROPERTY(QString installStatus READ installStatus NOTIFY installStatusChanged)
    Q_PROPERTY(bool simMode READ simMode CONSTANT)
public:
    explicit WelcomeBackend(QObject *parent = nullptr);
    ~WelcomeBackend() override;

    int step() const { return m_step; }
    bool completed() const { return m_completed; }
    QString userName() const { return m_userName; }
    QString avatarPath() const { return m_avatarPath; }
    QString language() const { return m_language; }
    QString appearance() const { return m_appearance; }
    QString accent() const { return m_accent; }
    QString layout() const { return m_layout; }
    QStringList wifiNetworks() const { return m_wifi; }
    QString wifiStatus() const { return m_wifiStatus; }
    QStringList selectedApps() const { return m_apps; }
    bool isInstalling() const { return m_installing; }
    int installProgress() const { return m_installProgress; }
    QString installStatus() const { return m_installStatus; }
    bool simMode() const { return m_sim; }
    Q_INVOKABLE int stepCount() const { return 7; }
    Q_INVOKABLE int stepIndexFor(const QString &name) const;

public Q_SLOTS:
    void setStep(int s);
    void setUserName(const QString &v);
    void setAvatarPath(const QString &v);
    void setLanguage(const QString &v);
    void setAppearance(const QString &v);
    void setAccent(const QString &v);
    void setLayout(const QString &v);
    void next();
    void back();
    void skip();   // omite: marca completado y pide cierre
    void finish(); // termina: marca completado y pide cierre
    void reset();  // borra el .ini (test / --reset)
    void scanWifi();                        // nmcli real o simulado
    void connectWifi(const QString &ssid, const QString &password);
    void toggleApp(const QString &id);
    void installApps();
    void cancelInstall();
    void applyAppearance(); // scripts/nimbus-theme si existe, si no config; sim en test
    void applyLayout();     // scripts/nimbus-layout <layout> --apply; sim: solo inis

Q_SIGNALS:
    void stepChanged();
    void completedChanged();
    void userNameChanged();
    void avatarPathChanged();
    void languageChanged();
    void appearanceChanged();
    void accentChanged();
    void layoutChanged();
    void wifiNetworksChanged();
    void wifiStatusChanged();
    void selectedAppsChanged();
    void isInstallingChanged();
    void installProgressChanged();
    void installStatusChanged();
    void requestQuit();

private:
    void load();
    void save() const;
    static QString iniPath();
    static bool simEnv();

    int m_step = 0;
    bool m_completed = false;
    QString m_userName;
    QString m_avatarPath;
    QString m_language = QStringLiteral("es");
    QString m_appearance = QStringLiteral("dark");
    QString m_accent = QStringLiteral("#0A84FF");
    QString m_layout = QStringLiteral("mac"); // Mac por defecto (F9-T03)
    QStringList m_wifi;
    QString m_wifiStatus;
    QStringList m_apps;
    bool m_installing = false;
    int m_installProgress = 0;
    QString m_installStatus;
    bool m_sim = false;
    QPointer<QProcess> m_installProcess;
};
