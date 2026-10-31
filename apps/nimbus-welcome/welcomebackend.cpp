// welcomebackend.cpp — F9-T02. Ver cabecera. Sin paquetes, sin root.
#include "welcomebackend.h"
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <cstdlib>

namespace {
const char *kSimEnv = "NIMBUS_WELCOME_SIM";
const char *kRepoEnv = "NIMBUS_REPO_ROOT";
const QStringList kSimWifi = { QStringLiteral("Casa-5G"),
                               QStringLiteral("Casa"),
                               QStringLiteral("Nimbus-Test") };
}

WelcomeBackend::WelcomeBackend(QObject *parent) : QObject(parent)
{
    m_sim = simEnv();
    load();
}

bool WelcomeBackend::simEnv()
{
    const char *v = std::getenv(kSimEnv);
    return v && QString::fromLocal8Bit(v) == QStringLiteral("1");
}

QString WelcomeBackend::iniPath()
{
    const QString cfg = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    return cfg + QStringLiteral("/nimbus-welcome.ini");
}

void WelcomeBackend::load()
{
    QSettings s(iniPath(), QSettings::IniFormat);
    m_step = qBound(0, s.value(QStringLiteral("wizard/step"), 0).toInt(), 5);
    m_completed = s.value(QStringLiteral("wizard/completed"), false).toBool();
    m_userName = s.value(QStringLiteral("user/name")).toString();
    m_avatarPath = s.value(QStringLiteral("user/avatar")).toString();
    m_language = s.value(QStringLiteral("user/language"), QStringLiteral("es")).toString();
    m_appearance = s.value(QStringLiteral("look/appearance"), QStringLiteral("dark")).toString();
    m_accent = s.value(QStringLiteral("look/accent"), QStringLiteral("#0A84FF")).toString();
    m_apps = s.value(QStringLiteral("apps/selected")).toStringList();
    m_wifiStatus = s.value(QStringLiteral("wifi/lastStatus")).toString();
    m_wifi = kSimWifi; // lista inicial simulada; scanWifi() la refresca
}

void WelcomeBackend::save() const
{
    QSettings s(iniPath(), QSettings::IniFormat);
    s.setValue(QStringLiteral("wizard/step"), m_step);
    s.setValue(QStringLiteral("wizard/completed"), m_completed);
    s.setValue(QStringLiteral("user/name"), m_userName);
    s.setValue(QStringLiteral("user/avatar"), m_avatarPath);
    s.setValue(QStringLiteral("user/language"), m_language);
    s.setValue(QStringLiteral("look/appearance"), m_appearance);
    s.setValue(QStringLiteral("look/accent"), m_accent);
    s.setValue(QStringLiteral("apps/selected"), m_apps);
    s.setValue(QStringLiteral("wifi/lastStatus"), m_wifiStatus);
    s.sync();
}

int WelcomeBackend::stepIndexFor(const QString &name) const
{
    const QString n = name.toLower();
    if (n == QStringLiteral("welcome")) return 0;
    if (n == QStringLiteral("lang") || n == QStringLiteral("idioma")) return 1;
    if (n == QStringLiteral("wifi")) return 2;
    if (n == QStringLiteral("account") || n == QStringLiteral("cuenta")) return 3;
    if (n == QStringLiteral("appearance") || n == QStringLiteral("apariencia")) return 4;
    if (n == QStringLiteral("final") || n == QStringLiteral("apps")
        || n == QStringLiteral("tour")) return 5;
    bool ok = false;
    const int i = n.toInt(&ok);
    if (ok) return qBound(0, i, 5);
    return -1;
}

void WelcomeBackend::setStep(int s)
{
    s = qBound(0, s, 5);
    if (s == m_step) return;
    m_step = s;
    save();
    Q_EMIT stepChanged();
}

void WelcomeBackend::setUserName(const QString &v)
{
    if (v == m_userName) return;
    m_userName = v;
    save();
    Q_EMIT userNameChanged();
}

void WelcomeBackend::setAvatarPath(const QString &v)
{
    if (v == m_avatarPath) return;
    m_avatarPath = v;
    save();
    Q_EMIT avatarPathChanged();
}

void WelcomeBackend::setLanguage(const QString &v)
{
    if (v != QStringLiteral("es") && v != QStringLiteral("en")) return;
    if (v == m_language) return;
    m_language = v;
    save();
    Q_EMIT languageChanged();
}

void WelcomeBackend::setAppearance(const QString &v)
{
    if (v != QStringLiteral("light") && v != QStringLiteral("dark")) return;
    if (v == m_appearance) return;
    m_appearance = v;
    save();
    Q_EMIT appearanceChanged();
}

void WelcomeBackend::setAccent(const QString &v)
{
    if (v == m_accent) return;
    m_accent = v;
    save();
    Q_EMIT accentChanged();
}

void WelcomeBackend::next()
{
    if (m_step < 5) setStep(m_step + 1);
    else finish();
}

void WelcomeBackend::back()
{
    if (m_step > 0) setStep(m_step - 1);
}

void WelcomeBackend::skip()
{
    m_completed = true;
    save();
    Q_EMIT completedChanged();
    Q_EMIT requestQuit();
}

void WelcomeBackend::finish()
{
    m_completed = true;
    save();
    Q_EMIT completedChanged();
    Q_EMIT requestQuit();
}

void WelcomeBackend::reset()
{
    QFile::remove(iniPath());
    m_step = 0;
    m_completed = false;
    m_userName.clear();
    m_avatarPath.clear();
    m_language = QStringLiteral("es");
    m_appearance = QStringLiteral("dark");
    m_accent = QStringLiteral("#0A84FF");
    m_apps.clear();
    m_wifiStatus.clear();
    m_wifi = kSimWifi;
    Q_EMIT stepChanged();
    Q_EMIT completedChanged();
}

void WelcomeBackend::scanWifi()
{
    if (!m_sim) {
        QProcess p;
        p.start(QStringLiteral("nmcli"),
                { QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("SSID"),
                  QStringLiteral("dev"), QStringLiteral("wifi"), QStringLiteral("list"),
                  QStringLiteral("--rescan"), QStringLiteral("yes") });
        if (p.waitForFinished(8000) && p.exitCode() == 0) {
            QStringList found;
            const QString out = QString::fromLocal8Bit(p.readAllStandardOutput());
            for (const QString &line : out.split(QLatin1Char('\n'))) {
                const QString ssid = line.trimmed();
                if (!ssid.isEmpty() && !found.contains(ssid)) found << ssid;
            }
            if (!found.isEmpty()) {
                m_wifi = found.mid(0, 8);
                m_wifiStatus = QStringLiteral(" Redes encontradas.");
                Q_EMIT wifiNetworksChanged();
                Q_EMIT wifiStatusChanged();
                return;
            }
        }
    }
    m_wifi = kSimWifi; // simulado o fallback sin nmcli
    m_wifiStatus = m_sim ? QStringLiteral(" Escaneo simulado (test).")
                         : QStringLiteral(" Escaneo simulado (sin nmcli).");
    Q_EMIT wifiNetworksChanged();
    Q_EMIT wifiStatusChanged();
}

void WelcomeBackend::connectWifi(const QString &ssid, const QString &password)
{
    if (ssid.isEmpty()) {
        m_wifiStatus = QStringLiteral(" Elige una red primero.");
        Q_EMIT wifiStatusChanged();
        return;
    }
    if (m_sim || password == QStringLiteral("test")) {
        m_wifiStatus = QStringLiteral(" Conectado a %1 (simulado).").arg(ssid);
        Q_EMIT wifiStatusChanged();
        save();
        return;
    }
    QProcess p;
    p.start(QStringLiteral("nmcli"),
            { QStringLiteral("dev"), QStringLiteral("wifi"), QStringLiteral("connect"),
              ssid, QStringLiteral("password"), password });
    if (p.waitForFinished(15000) && p.exitCode() == 0) {
        m_wifiStatus = QStringLiteral(" Conectado a %1.").arg(ssid);
    } else {
        m_wifiStatus = QStringLiteral(" No se pudo conectar (puedes omitir este paso).");
    }
    Q_EMIT wifiStatusChanged();
    save();
}

void WelcomeBackend::toggleApp(const QString &id)
{
    if (m_apps.contains(id)) m_apps.removeAll(id);
    else m_apps << id;
    save();
    Q_EMIT selectedAppsChanged();
}

void WelcomeBackend::applyAppearance()
{
    if (m_sim) return; // test: simula, no cambia el sistema
    const char *repo = std::getenv(kRepoEnv);
    QString script = repo ? QString::fromLocal8Bit(repo) + QStringLiteral("/scripts/nimbus-theme")
                          : QStringLiteral("nimbus-theme");
    const bool hasScript = repo ? QFile::exists(script) : !QStandardPaths::findExecutable(script).isEmpty();
    if (hasScript) {
        QProcess::startDetached(script, { m_appearance, QStringLiteral("--accent"), m_accent });
        return;
    }
    // Fallback sin script: solo config (sin sesión viva, sin paquetes).
    QProcess::execute(QStringLiteral("kwriteconfig6"),
                      { QStringLiteral("--file"), QStringLiteral("kdeglobals"),
                        QStringLiteral("--group"), QStringLiteral("General"),
                        QStringLiteral("--key"), QStringLiteral("ColorScheme"),
                        m_appearance == QStringLiteral("light")
                            ? QStringLiteral("NimbusTahoeLight")
                            : QStringLiteral("NimbusTahoe") });
}
