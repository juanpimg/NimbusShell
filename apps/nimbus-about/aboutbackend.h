// aboutbackend.h — F10-T01. Datos del sistema para "Acerca de Nimbus".
// Sin KF. Fuentes: /proc/sys/kernel/osrelease, `plasmashell --version`,
// `qmake6 -query QT_VERSION`, `kwin_wayland --version`, /proc/cpuinfo,
// /proc/meminfo, `lspci` (GPU, mejor esfuerzo). NIMBUS_ABOUT_SIM=1 simula.
#pragma once
#include <QObject>
#include <QString>

class AboutBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(QString kernel READ kernel NOTIFY infoChanged)
    Q_PROPERTY(QString plasmaVersion READ plasmaVersion NOTIFY infoChanged)
    Q_PROPERTY(QString qtVersion READ qtVersion NOTIFY infoChanged)
    Q_PROPERTY(QString kwinVersion READ kwinVersion NOTIFY infoChanged)
    Q_PROPERTY(QString cpu READ cpu NOTIFY infoChanged)
    Q_PROPERTY(QString ram READ ram NOTIFY infoChanged)
    Q_PROPERTY(QString gpu READ gpu NOTIFY infoChanged)
    Q_PROPERTY(QString credits READ credits CONSTANT)
    Q_PROPERTY(bool simMode READ simMode CONSTANT)
public:
    explicit AboutBackend(QObject *parent = nullptr);
    QString version() const { return QStringLiteral("2026.11"); }
    QString osName() const { return QStringLiteral("NimbusShell (Plasma)"); }
    QString kernel() const { return m_kernel; }
    QString plasmaVersion() const { return m_plasma; }
    QString qtVersion() const { return m_qt; }
    QString kwinVersion() const { return m_kwin; }
    QString cpu() const { return m_cpu; }
    QString ram() const { return m_ram; }
    QString gpu() const { return m_gpu; }
    QString credits() const;
    bool simMode() const { return m_sim; }
    Q_INVOKABLE QString infoText() const;
    Q_INVOKABLE void copyInfo();
    Q_INVOKABLE void openHelp(const QString &tab);
Q_SIGNALS:
    void infoChanged();
private:
    void collect();
    static QString runCmd(const QString &prog, const QStringList &args, int timeoutMs = 3000);
    QString m_kernel, m_plasma, m_qt, m_kwin, m_cpu, m_ram, m_gpu;
    bool m_sim = false;
};
