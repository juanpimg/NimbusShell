// helpbackend.h — F11-T06. Visor offline de docs/user-guide (README.md,
// shortcuts.md) + docs/user (índice es/en). Sin red. NIMBUS_GUIDE_DIR
// sobrescribe la ruta (tests/nested).
#pragma once
#include <QObject>
#include <QString>

class HelpBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString guideText READ guideText NOTIFY docsChanged)
    Q_PROPERTY(QString shortcutsText READ shortcutsText NOTIFY docsChanged)
    Q_PROPERTY(QString indexText READ indexText NOTIFY docsChanged)
    Q_PROPERTY(QString guidePath READ guidePath NOTIFY docsChanged)
public:
    explicit HelpBackend(QObject *parent = nullptr);
    QString language() const { return m_lang; }
    QString guideText() const { return m_guide; }
    QString shortcutsText() const { return m_short; }
    QString indexText() const { return m_index; }
    QString guidePath() const { return m_dir; }
    Q_INVOKABLE void setLanguage(const QString &lang);
Q_SIGNALS:
    void languageChanged();
    void docsChanged();
private:
    void load();
    static QString baseDir();
    static QString readFile(const QString &p);
    QString m_lang = QStringLiteral("es");
    QString m_guide, m_short, m_index, m_dir;
};
