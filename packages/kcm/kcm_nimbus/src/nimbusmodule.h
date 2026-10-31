// F8-T01 — KCM Nimbus (esqueleto, 6 páginas).
// Ruling F8-T01-API: el brief (docs/plans/research/F8-kcm.md §1) propone
// KQuickAddons::ManagedConfigModule + kcfgc, pero en Plasma 6.8 instalado
// (KF6 6.31) no existe KQuickAddons ni kconfig_compiler_kf6; la clase vigente
// es KQuickConfigModule (KCMUtilsQuick) con load()/save()/defaults() manuales
// vía KConfigGroup. Ruling F8-T01-NOECM: sin extra-cmake-modules en el host,
// CMake autocontenido (GNUInstallDirs) que replica el layout de
// kcmutils_add_qml_kcm (qrc :/kcm/kcm_nimbus/ui/*.qml + .so en plasma/kcms).
#pragma once

#include <KQuickConfigModule>

class NimbusModule : public KQuickConfigModule
{
    Q_OBJECT
    // Tema real: refleja kdeglobals [General] ColorScheme (F8-T02 lo amplía).
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)

public:
    explicit NimbusModule(QObject *parent, const KPluginMetaData &metaData);

    bool darkMode() const;
    void setDarkMode(bool dark);
    QString accentColor() const;
    void setAccentColor(const QString &color);

    // Salto a KCMs existentes (embeber por salto, F8-kcm.md §2): nunca crashea
    // si el destino no está instalado; devuelve false en ese caso.
    Q_INVOKABLE bool openKcm(const QString &kcmId);
    // Lanza una app por binario (p. ej. Discover). Best-effort, nunca falla.
    Q_INVOKABLE bool openApp(const QString &binary);
    // Lanza scripts/nimbus-theme si está en PATH (best-effort, nunca falla).
    Q_INVOKABLE void applySystemTheme();

public Q_SLOTS:
    void load() override;
    void save() override;
    void defaults() override;

Q_SIGNALS:
    void darkModeChanged();
    void accentColorChanged();

private:
    void readConfig();
    bool m_darkMode = true;
    QString m_accentColor = QStringLiteral("#0A84FF");
    bool m_loaded = false;
};
