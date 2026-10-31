// F8-T01 — implementación. Persistencia mínima en kdeglobals (canal real
// Plasma 6.8, ver scripts/nimbus-theme): [General] ColorScheme y
// [KDE] LookAndFeelPackage. Sin KAuth (F8-T06), sin root, sin hilos.
#include "nimbusmodule.h"

#include <KConfigGroup>
#include <KPluginFactory>
#include <KSharedConfig>
#include <QProcess>
#include <QStandardPaths>

K_PLUGIN_CLASS_WITH_JSON(NimbusModule, "metadata.json")

namespace
{
constexpr char kColorSchemeKey[] = "ColorScheme";
constexpr char kLookAndFeelKey[] = "LookAndFeelPackage";
constexpr char kLightScheme[] = "BreezeLight";
constexpr char kDarkScheme[] = "BreezeDark";
constexpr char kLightLook[] = "org.kde.breeze.desktop";
constexpr char kDarkLook[] = "org.kde.breezedark.desktop";
// Contrato Tahoe §2.1: acento #007AFF (light) / #0A84FF (dark) [HIG].
constexpr char kLightAccent[] = "#007AFF";
constexpr char kDarkAccent[] = "#0A84FF";
}

NimbusModule::NimbusModule(QObject *parent, const KPluginMetaData &metaData)
    : KQuickConfigModule(parent, metaData)
{
    setButtons(Apply | Default);
}

bool NimbusModule::darkMode() const
{
    return m_darkMode;
}

void NimbusModule::setDarkMode(bool dark)
{
    if (m_darkMode == dark) {
        return;
    }
    m_darkMode = dark;
    // Acento canónico del modo si el usuario no fijó uno propio.
    m_accentColor = dark ? QString::fromLatin1(kDarkAccent) : QString::fromLatin1(kLightAccent);
    Q_EMIT darkModeChanged();
    Q_EMIT accentColorChanged();
    if (m_loaded) {
        setNeedsSave(true);
    }
}

QString NimbusModule::accentColor() const
{
    return m_accentColor;
}

void NimbusModule::setAccentColor(const QString &color)
{
    if (color.isEmpty() || m_accentColor == color) {
        return;
    }
    m_accentColor = color;
    Q_EMIT accentColorChanged();
    if (m_loaded) {
        setNeedsSave(true);
    }
}

bool NimbusModule::openKcm(const QString &kcmId)
{
    if (kcmId.isEmpty()) {
        return false;
    }
    const QString shell = QStandardPaths::findExecutable(QStringLiteral("kcmshell6"));
    if (shell.isEmpty()) {
        return false;
    }
    return QProcess::startDetached(shell, {kcmId});
}

bool NimbusModule::openApp(const QString &binary)
{
    if (binary.isEmpty()) {
        return false;
    }
    const QString exe = QStandardPaths::findExecutable(binary);
    if (exe.isEmpty()) {
        return false;
    }
    return QProcess::startDetached(exe, {});
}

void NimbusModule::applySystemTheme()
{
    const QString helper = QStandardPaths::findExecutable(QStringLiteral("nimbus-theme"));
    if (helper.isEmpty()) {
        return;
    }
    QStringList args{ m_darkMode ? QStringLiteral("dark") : QStringLiteral("light"),
                      QStringLiteral("--accent"), m_accentColor };
    QProcess::startDetached(helper, args);
}

void NimbusModule::readConfig()
{
    const KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    const KConfigGroup general(config, QStringLiteral("General"));
    const QString scheme = general.readEntry(kColorSchemeKey, QString::fromLatin1(kDarkScheme));
    m_darkMode = scheme.contains(QStringLiteral("Dark"), Qt::CaseInsensitive);
    if (m_darkMode) {
        m_accentColor = QString::fromLatin1(kDarkAccent);
    } else {
        m_accentColor = QString::fromLatin1(kLightAccent);
    }
}

void NimbusModule::load()
{
    readConfig();
    m_loaded = true;
    setNeedsSave(false);
    setRepresentsDefaults(m_darkMode && m_accentColor == QLatin1String(kDarkAccent));
    Q_EMIT darkModeChanged();
    Q_EMIT accentColorChanged();
}

void NimbusModule::save()
{
    KSharedConfig::Ptr config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"));
    KConfigGroup general(config, QStringLiteral("General"));
    general.writeEntry(kColorSchemeKey, m_darkMode ? QString::fromLatin1(kDarkScheme) : QString::fromLatin1(kLightScheme));
    KConfigGroup kde(config, QStringLiteral("KDE"));
    kde.writeEntry(kLookAndFeelKey, m_darkMode ? QString::fromLatin1(kDarkLook) : QString::fromLatin1(kLightLook));
    config->sync();
    applySystemTheme();
    setNeedsSave(false);
}

void NimbusModule::defaults()
{
    m_darkMode = true;
    m_accentColor = QString::fromLatin1(kDarkAccent);
    Q_EMIT darkModeChanged();
    Q_EMIT accentColorChanged();
    setNeedsSave(true);
    setRepresentsDefaults(true);
}

#include "nimbusmodule.moc"
