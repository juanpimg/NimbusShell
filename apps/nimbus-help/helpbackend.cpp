// helpbackend.cpp — F11-T06. Ver cabecera.
#include "helpbackend.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <cstdlib>

namespace {
const char *kGuideEnv = "NIMBUS_GUIDE_DIR";
const char *kRepoEnv = "NIMBUS_REPO_ROOT";
}

QString HelpBackend::readFile(const QString &p)
{
    QFile f(p);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QTextStream(&f).readAll();
}

QString HelpBackend::baseDir()
{
    if (const char *e = std::getenv(kGuideEnv))
        if (!QString::fromLocal8Bit(e).isEmpty())
            return QString::fromLocal8Bit(e);
    for (const QString &c : { QStringLiteral("/usr/share/nimbus/user-guide"),
                              QStringLiteral("/usr/local/share/nimbus/user-guide") }) {
        if (QDir(c).exists())
            return c;
    }
    if (const char *r = std::getenv(kRepoEnv)) {
        const QString d = QString::fromLocal8Bit(r) + QStringLiteral("/docs/user-guide");
        if (QDir(d).exists())
            return d;
    }
    for (const QString &d : { QStringLiteral("docs/user-guide"),
                              QStringLiteral("../docs/user-guide"),
                              QStringLiteral("../../docs/user-guide") }) {
        if (QDir(d).exists())
            return QDir(d).absolutePath();
    }
    return {};
}

HelpBackend::HelpBackend(QObject *parent) : QObject(parent) { load(); }

void HelpBackend::setLanguage(const QString &lang)
{
    const QString l = (lang == QStringLiteral("en")) ? QStringLiteral("en") : QStringLiteral("es");
    if (l == m_lang && !m_guide.isEmpty())
        return;
    m_lang = l;
    load();
    Q_EMIT languageChanged();
}

void HelpBackend::load()
{
    m_dir = baseDir();
    const QString repoRoot = []() -> QString {
        if (const char *r = std::getenv(kRepoEnv))
            return QString::fromLocal8Bit(r);
        return {};
    }();
    if (m_dir.isEmpty()) {
        m_guide = QStringLiteral("# Sin documentos\nNo se encontró la guía offline.");
        m_short = m_guide;
        m_index = m_guide;
        Q_EMIT docsChanged();
        return;
    }
    if (m_lang == QStringLiteral("en")) {
        // EN breve: README inglés si existe, si no aviso + guía ES.
        QString enIdx = !repoRoot.isEmpty() ? readFile(repoRoot + QStringLiteral("/docs/user/en/README.md")) : QString();
        QString enGuide = m_dir + QStringLiteral("/README.en.md");
        m_guide = readFile(enGuide);
        if (m_guide.isEmpty())
            m_guide = enIdx.isEmpty()
                ? QStringLiteral("# User guide (EN)\n\nFull guide available in Spanish. See Guía tab.")
                : enIdx;
        m_short = m_guide;
        m_index = m_guide;
    } else {
        m_guide = readFile(m_dir + QStringLiteral("/README.md"));
        m_short = readFile(m_dir + QStringLiteral("/shortcuts.md"));
        QString idx = !repoRoot.isEmpty() ? readFile(repoRoot + QStringLiteral("/docs/user/README.md")) : QString();
        m_index = idx.isEmpty() ? m_guide.left(2000) : idx;
        if (m_guide.isEmpty())
            m_guide = QStringLiteral("# Sin documentos\nNo se pudo leer README.md.");
        if (m_short.isEmpty())
            m_short = QStringLiteral("# Sin atajos\nNo se pudo leer shortcuts.md.");
    }
    Q_EMIT docsChanged();
}
